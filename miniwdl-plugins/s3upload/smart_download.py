from collections import defaultdict
from typing import DefaultDict, Dict, Set

from WDL import Env, Error, Expr, Tree, Type, Value


_null_source_pos = Error.SourcePosition("", "", 0, 0, 0, 0)


def _build_download_task():
    uri_input = Tree.Decl(-1, Type.String(), 'uri')
    # TODO: actually download
    command = Expr.String(_null_source_pos, ['"mkdir __out/; echo nooooo > __out/foo.txt"'], True)
    output = Tree.Decl(-1, Type.File(), 'file', Expr.Apply(-1, '_at', [Expr.Apply(-1, 'glob', [Expr.String(-1, '"__out/*"')]), Expr.Int(-1, 0)]))

    task = Tree.Task(
        pos=_null_source_pos,
        name='s3parcp',
        inputs=[uri_input],
        postinputs=[],
        command=command,
        outputs=[output],
        parameter_meta={},
        runtime={
            # TODO: real docker
            'docker':Expr.String(_null_source_pos, ['"ubuntu:22.04"']),
        },
        meta={} 
    )
    task.parent = Tree.Document("", _null_source_pos, [], {}, [task], None, [], '')
    return task


def _build_download_call(download_task: Tree.Task, uri: Tree.Decl):
    call = Tree.Call(
        pos=-1,
        callee_id=[download_task.name],
        alias=f'{download_task.name}_{uri.name}',
        inputs={
            'uri': Expr.Get(_null_source_pos, Expr.Ident(_null_source_pos, uri.name), None),
        },
    )
    call.callee = download_task
    call._memo_workflow_node_dependencies = {uri.workflow_node_id}
    return call


def _remap_expr(expr: Expr.Base, downlad_call: Tree.Call, name: str):
    exprs = [expr]
    while exprs:
        _expr = exprs.pop()
        if isinstance(_expr, Expr.Ident) and _expr.name == name:
            _expr.pos = _null_source_pos
            _expr.name = f'{downlad_call.name}.file'
            _expr.referee = downlad_call
        else:
            exprs += list(_expr.children)


def smart_download(inputs: Env.Bindings, workflow: Tree.Workflow):
    nodes_by_id: Dict[str, Tree.WorkflowNode] = {}
    node_dependencies: DefaultDict[str, Set[str]] = defaultdict(set)
    for _input in workflow.inputs:
        node_dependencies[_input.workflow_node_id] = set()
    to_traverse = [ e for e in workflow.body ]
    while to_traverse:
        current = to_traverse.pop()
        print('BBBBBBBBBBBBBBBBBBBBBBBBBB', current.__class__)
        node_dependencies[current.workflow_node_id].update(current.workflow_node_dependencies)
        nodes_by_id[current.workflow_node_id] = current

        if isinstance(current, Tree.Scatter):
            for child in current.children:
                if isinstance(child, Tree.WorkflowNode):
                    node_dependencies[child.workflow_node_id].add(current.workflow_node_id)
                    to_traverse.append(child)
        if isinstance(current, Tree.Conditional):
            for child in current.children:
                if isinstance(child, Tree.WorkflowNode):
                    node_dependencies[child.workflow_node_id].add(current.workflow_node_id)
                    to_traverse.append(child)

    inputs_to_remap = []
    for _input in workflow.inputs:
        if isinstance(_input.type, Type.File):
            try:
                provided_input = inputs.resolve_binding(_input.name)
            except KeyError:
                provided_input = None

            if provided_input:
                filepath = provided_input.value.value
                provided_input._value = Value.String(provided_input.value.value)
            elif isinstance(_input.expr, Expr.String):
                filepath = _input.expr.parts[0]
            if filepath.startswith('s3://'):
                _input.type = Type.String(_input.type.optional)
                inputs_to_remap.append(_input)

    for _input in inputs_to_remap:
        download_task = _build_download_task()
        download_call = _build_download_call(download_task, _input)
        workflow.body.append(download_call)
        for k, v in node_dependencies.items():
            if any(node == _input.workflow_node_id for node in v):
                node = nodes_by_id[k]
                node._memo_workflow_node_dependencies.add(download_call.workflow_node_id)
                if isinstance(node, Tree.Call):
                    for node_input in node.inputs.values():
                        _remap_expr(node_input, download_call, _input.name)
                if isinstance(node, Tree.Scatter):
                    _remap_expr(node.expr, download_call, _input.name)
                if isinstance(node, Tree.Conditional):
                    _remap_expr(node.expr, download_call, _input.name)
                # if isinstance(node, Tree.Decl):
                #     _remap_expr(node.expr, download_call, _input.name)

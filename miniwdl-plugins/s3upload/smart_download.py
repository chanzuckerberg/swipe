import logging
from typing import Dict
from uuid import uuid4


from WDL.runtime import config
from WDL import Env, Error, Expr, Tree, Type, Value

import boto3


_download_output_name = 'out'
_null_source_pos = Error.SourcePosition("", "", 0, 0, 0, 0)
_task_name = f'{uuid4()}_s3parcp'


def _build_download_task(cfg: config.Loader, directory: bool):
    global _task_name

    uri_input = Tree.Decl(_null_source_pos, Type.String(), 'uri')

    uri_placeholder = Expr.Placeholder(_null_source_pos, {}, Expr.Ident(_null_source_pos, 'uri'))
    flags = '--recursive' if directory else ''
    command = Expr.String(
        _null_source_pos,
        [
            f' set -euxo; mkdir __out/; cd __out/ ; s3parcp {flags} ',
            uri_placeholder,
            ' .  ',
        ],
        True,
    )

    if directory:
        output = Tree.Decl(_null_source_pos, Type.Directory(), 'out', Expr.String(_null_source_pos, ' __out/ '))
    else:
        output = Tree.Decl(
            _null_source_pos,
            Type.File(),
            _download_output_name,
            Expr.Apply(
                _null_source_pos,
                '_at',
                [
                    Expr.Apply(_null_source_pos, 'glob', [Expr.String(_null_source_pos, ' __out/* ')]),
                    Expr.Int(_null_source_pos, 0),
                ],
            ),
        )

    task = Tree.Task(
        pos=_null_source_pos,
        name=_task_name,
        inputs=[uri_input],
        postinputs=[],
        command=command,
        outputs=[output],
        parameter_meta={},
        runtime={
            'docker': Expr.String(_null_source_pos, [f' {cfg["s3parcp"]["docker_image"] } ']),
        },
        meta={},
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
            _expr.name = f'{downlad_call.name}.{_download_output_name}'
            _expr.referee = downlad_call
        else:
            exprs += list(_expr.children)


def _inputs_to_remap(inputs: Env.Bindings, workflow: Tree.Workflow):
    for _input in workflow.inputs:
        if isinstance(_input.type, Type.File) or isinstance(_input.type, Type.Directory):
            try:
                provided_input = inputs.resolve_binding(_input.name)
            except KeyError:
                provided_input = None

            if provided_input:
                filepath = provided_input.value.value
            elif isinstance(_input.expr, Expr.String):
                assert len(_input.expr.parts) == 1
                assert isinstance(_input.expr.parts[0], str)
                filepath = _input.expr.parts[0]
            # TODO: generalize
            if filepath.startswith('s3://'):
                if provided_input:
                    provided_input._value = Value.String(provided_input.value.value)
                yield _input


def smart_download(cfg: config.Loader, inputs: Env.Bindings, workflow: Tree.Workflow):
    nodes_by_id: Dict[str, Tree.WorkflowNode] = {}
    remaining_nodes = workflow.body.copy()
    while remaining_nodes:
        node = remaining_nodes.pop()
        nodes_by_id[node.workflow_node_id] = node
        remaining_nodes += [
            child for child in node.children if isinstance(child, Tree.WorkflowNode)
        ]

    for _input in _inputs_to_remap(inputs, workflow):
        download_task = _build_download_task(cfg, isinstance(_input.type, Type.Directory))
        _input.type = Type.String(_input.type.optional)
        download_call = _build_download_call(download_task, _input)
        workflow.body.append(download_call)
        for node in nodes_by_id.values():
            if _input.workflow_node_id in node.workflow_node_dependencies:
                node._memo_workflow_node_dependencies.add(download_call.workflow_node_id)
                node._memo_workflow_node_dependencies.remove(_input.workflow_node_id)
                for child in node.children:
                    if isinstance(child, Expr.Base):
                        _remap_expr(child, download_call, _input.name)


def task_plugin(cfg: config.Loader, logger: logging.Logger, run_id: str, run_dir: str, task: Tree.Task, **recv):
    """
    Adds credentials to downloader tasks
    """
    recv = yield recv
    if task.name == _task_name:
        # get AWS credentials from boto3
        b3 = boto3.session.Session()
        b3creds = b3.get_credentials()
        aws_credentials: Dict[str, str] = {
            "AWS_ACCESS_KEY_ID": b3creds.access_key,
            "AWS_SECRET_ACCESS_KEY": b3creds.secret_key,
        }
        if b3creds.token:
            aws_credentials["AWS_SESSION_TOKEN"] = b3creds.token

        # s3parcp (or perhaps underlying golang AWS lib) seems to require region set to match the
        # bucket's; in contrast to awscli which can conveniently 'figure it out'
        aws_credentials["AWS_REGION"] = b3.region_name if b3.region_name else "us-west-2"

        recv['container'].runtime_values.setdefault('env', {})
        for k, v in aws_credentials.items():
            recv['container'].runtime_values['env'][k] = v

        # ignore command/runtime/container
        recv = yield recv
    else:
        # ignore command/runtime/container
        recv = yield recv
    yield recv

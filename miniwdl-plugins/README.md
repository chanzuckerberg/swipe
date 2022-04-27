# miniwdl-plugins

These plugins are copied from the [miniwdl-plugins](https://github.com/chanzuckerberg/miniwdl-plugins) repo. That repo is home to several [miniwdl](https://github.com/chanzuckerberg/miniwdl) plugins. We felt these plugins may potentially be useful to others but over time it has become clear that the implementation of the plugins is tightly coupled to our swipe architecture. This resulted in the need for frequent swipe-specific updates to those plugins. These updates are not relevant to other potential users of the plugin and having them in a separate repository complicated our development cycle and testing process so we decided to start tracking this code as part of the swipe repo.

These plugins are installed in the swipe docker image so we can run end to end tests of their functionality with our testing tools. This should enable more rapid development and testing as well as clearer version control for this code.

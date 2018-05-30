/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
detox-core	= require('@detox/core')

const NUMBER_OF_NODES		= 50
const bootstrap_node_id		= '3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29'
const bootstrap_ip			= '127.0.0.1'
const bootstrap_port		= 16882
const bootstrap_node_info	= "#bootstrap_node_id:#bootstrap_ip:#bootstrap_port"

<-! detox-core.ready

global.nodes	= []
wait_for		= NUMBER_OF_NODES
options			=
	connected_nodes_limit	: 30
	lookup_number			: 3
promise			= Promise.resolve()

for let i from 0 til NUMBER_OF_NODES
	promise		:= promise.then ->
		new Promise (resolve) !->
			if i == 0
				instance	= detox-core.Core([], [], 5, 20, Object.assign({}, options, {connected_nodes_limit : NUMBER_OF_NODES}))
				instance.start_bootstrap_node(new Uint8Array(32), bootstrap_ip, bootstrap_port)
			else
				instance	= detox-core.Core([bootstrap_node_info], [], 5, 2, options)
			instance.once('ready', !->
				console.log('Node ' + i + ' is ready, #' + (NUMBER_OF_NODES - wait_for + 1) + '/' + NUMBER_OF_NODES)

				--wait_for
				if !wait_for
					ready_callback()
			)
			nodes.push(instance)
			setTimeout(resolve, 100)

!function ready_callback
	console.log "All nodes are ready, connect to bootstrap node using #bootstrap_node_id:#bootstrap_ip:#bootstrap_port"

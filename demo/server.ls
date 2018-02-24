/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
detox-chat	= require('..')
detox-core	= require('@detox/core')
test		= require('tape')

const NUMBER_OF_NODES		= 10
const bootstrap_node_id		= '3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29'
const bootstrap_ip			= '127.0.0.1'
const bootstrap_port		= 16882
const bootstrap_node_info	=
	node_id	: bootstrap_node_id
	host	: bootstrap_ip
	port	: bootstrap_port

<-! detox-chat.ready

nodes		= []
wait_for	= NUMBER_OF_NODES

for let i from 0 til NUMBER_OF_NODES
	if i == 0
		instance	= detox-core.Core(new Uint8Array(32), [], [], 5, 10)
		instance.start_bootstrap_node(bootstrap_ip, bootstrap_port)
	else
		instance	= detox-core.Core(detox-chat.generate_seed(), [bootstrap_node_info], [], 5)
	instance.once('ready', !->
		console.log('Node ' + i + ' is ready, #' + (NUMBER_OF_NODES - wait_for + 1) + '/' + NUMBER_OF_NODES)

		--wait_for
		if !wait_for
			ready_callback()
	)
	nodes.push(instance)

!function ready_callback
	console.log "All nodes are ready, connect to bootstrap node at #bootstrap_ip:#bootstrap_port with ID #bootstrap_node_id"

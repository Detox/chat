/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
requirejs.config(
	baseUrl		: '/node_modules/'
	paths		:
		'@detox/chat'				: '/src/index'
		'@detox/core'				: '@detox/core/src/index'
		'@detox/crypto'				: '@detox/crypto/src/index'
		'@detox/dht'				: '@detox/dht/dist/detox-dht.browser'
		'@detox/transport'			: '@detox/transport/src/index'
		'@detox/utils'				: '@detox/utils/src/index'
		'async-eventer'				: 'async-eventer/src/index'
		'fixed-size-multiplexer'	: 'fixed-size-multiplexer/src/index'
		'ronion'					: 'ronion/dist/ronion.browser'
		'pako'						: 'pako/dist/pako'
	packages	: [
		{
			name		: 'aez.wasm',
			location	: 'aez.wasm',
			main		: 'src/index'
		}
		{
			name		: 'ed25519-to-x25519.wasm',
			location	: 'ed25519-to-x25519.wasm',
			main		: 'src/index'
		}
		{
			name		: 'noise-c.wasm',
			location	: 'noise-c.wasm',
			main		: 'src/index'
		}
		{
			name		: 'supercop.wasm',
			location	: 'supercop.wasm',
			main		: 'src/index'
		}
	]
)

const NUMBER_OF_NODES		= 2
const bootstrap_node_id		= '3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29'
const bootstrap_ip			= '127.0.0.1'
const bootstrap_port		= 16882
const bootstrap_node_info	=
	node_id	: bootstrap_node_id
	host	: bootstrap_ip
	port	: bootstrap_port

([detox-chat, detox-core, detox-crypto, detox-utils]) <-! require(['@detox/chat', '@detox/core', '@detox/crypto', '@detox/utils']).then
<-! detox-chat.ready

window.nodes	= []
wait_for		= NUMBER_OF_NODES

!function log (message)
	console.log message
	document.querySelector('#status').textContent	= message

for let i from 0 til NUMBER_OF_NODES
	instance	= detox-core.Core(detox-chat.generate_seed(), [bootstrap_node_info], [], 5)
	instance.once('ready', !->
		log('Node ' + i + ' is ready, #' + (NUMBER_OF_NODES - wait_for + 1) + '/' + NUMBER_OF_NODES)

		--wait_for
		if !wait_for
			ready_callback()
	)
	nodes.push(instance)

!function ready_callback
	core_instance_0	= nodes[0]
	core_instance_1	= nodes[1]

	log 'Creating chat instances...'
	chat_seed_0		= detox-utils.random_bytes(32)
	chat_seed_1		= detox-utils.random_bytes(32)
	chat_keypair_0	= detox-crypto.create_keypair(chat_seed_0)
	chat_keypair_1	= detox-crypto.create_keypair(chat_seed_1)
	chat_instance_0	= detox-chat.Chat(core_instance_0, chat_seed_0)
	chat_instance_1	= detox-chat.Chat(core_instance_1, chat_seed_1)

	window.chat_nodes		= [chat_instance_0, chat_instance_1]
	window.chat_opponents	= [chat_keypair_1.ed25519.public, chat_keypair_0.ed25519.public]

	<-! detox-utils.timeoutSet(2, _)
	log 'Announcing node 1 to the network...'
	chat_instance_1.on('announced', !->
		log 'Announced, connecting from node 0 to node 1...'
		chat_instance_0
			.on('connected', !->
				log 'Connected, you can chat now!'
			)
			.on('connection_failed', (, reason) !->
				log "Connection failed, reason code #reason, trying again in 1s"

				detox-utils.timeoutSet(1, !->
					chat_instance_0.connect_to(chat_keypair_1.ed25519.public, new Uint8Array(0))
				)
			)
		chat_instance_0.connect_to(chat_keypair_1.ed25519.public, new Uint8Array(0))
	)
	chat_instance_1.announce()

	for let chat_element, index in Array.from(document.querySelectorAll('.chat'))
		textarea		= chat_element.querySelector('textarea')
		messages		= chat_element.querySelector('div')
		chat_node		= chat_nodes[index]
		chat_opponent	= chat_opponents[index]
		chat_element.querySelector('button').addEventListener('click', !->
			chat_node.text_message(chat_opponent, textarea.value)
			messages.prepend (
				document.createElement('div')
					..textContent	= textarea.value
					..classList.add('right')
			)
			textarea.value = ''
		)
		chat_node.on('text_message', (, , message) !->
			messages.prepend (
				document.createElement('div')
					..textContent	= message
			)
		)

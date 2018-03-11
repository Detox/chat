/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
detox-core		= require('@detox/core')
detox-crypto	= require('@detox/crypto')
lib				= require('..')
test			= require('tape')

const NUMBER_OF_NODES		= 10
const bootstrap_node_id		= '3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29'
const bootstrap_ip			= '127.0.0.1'
const bootstrap_port		= 16882
const bootstrap_node_info	=
	node_id	: bootstrap_node_id
	host	: bootstrap_ip
	port	: bootstrap_port
const plaintext				= 'Hello, Detox chat!'

<-! lib.ready
test('Core', (t) !->
	t.plan(NUMBER_OF_NODES + 18)

	generated_seed	= lib.generate_seed()
	t.ok(generated_seed instanceof Uint8Array, 'Seed is Uint8Array')
	t.equal(generated_seed.length, 32, 'Seed length is 32 bytes')

	generated_secret	= lib.generate_secret()
	t.ok(generated_secret instanceof Uint8Array, 'Secret is Uint8Array')
	t.equal(generated_secret.length, 32, 'Secret length is 32 bytes')

	node_1_real_seed		= new Uint8Array(32)
		..set([1, 1])
	node_1_real_public_key	= detox-crypto.create_keypair(node_1_real_seed).ed25519.public
	node_3_real_seed		= new Uint8Array(32)
		..set([3, 1])
	node_3_real_public_key	= detox-crypto.create_keypair(node_3_real_seed).ed25519.public

	nodes	= []

	wait_for	= NUMBER_OF_NODES
	for let i from 0 til NUMBER_OF_NODES
		dht_seed	= new Uint8Array(32)
			..set([i])
		if i == 0
			instance	= detox-core.Core(dht_seed, [], [], 5, 10)
			instance.start_bootstrap_node(bootstrap_ip, bootstrap_port)
		else
			instance	= detox-core.Core(dht_seed, [bootstrap_node_info], [], 5)
		instance.once('ready', !->
			t.pass('Node ' + i + ' is ready, #' + (NUMBER_OF_NODES - wait_for + 1) + '/' + NUMBER_OF_NODES)

			--wait_for
			if !wait_for
				ready_callback()
		)
		nodes.push(instance)

	!function destroy_nodes
		console.log 'Destroying nodes...'
		for node in nodes
			node.destroy()
		console.log 'Destroyed'

	!function ready_callback
		node_1	= nodes[1]
		node_3	= nodes[3]

		chat_node_1	= lib.Chat(node_1, node_1_real_seed)
		chat_node_3	= lib.Chat(node_3, node_3_real_seed)

		t.deepEqual(node_1.get_bootstrap_nodes()[0], bootstrap_node_info, 'Bootstrap nodes are returned correctly')

		t.equal(node_1.get_max_data_size(), 2 ** 16 - 1, 'Max data size returned correctly')

		chat_node_1.once('announced', !->
			t.pass('Node 1 announced successfully')

			console.log 'Preparing for connection (5s)...'
			# Hack to make sure at least one announcement reaches corresponding DHT node at this point
			setTimeout (!->
				console.log 'Connecting...'

				chat_node_1
					.on('introduction', (, secret) !->
						t.equal(secret.join(','), generated_secret.join(','), 'Correct secret received on introduction')
					)
					.on('secret', (, secret) !->
						t.equal(secret.join(','), generated_secret.join(','), 'Correct secret received in secret event on node 1')

						chat_node_1.secret(node_3_real_public_key, generated_secret)
					)
					.on('secret_received', !->
						t.pass('Secret received on node 1')
					)
					.on('nickname', (, nickname) !->
						t.equal(nickname, 'Node 3', 'Correct nickname received on node 1')
					)
					.on('text_message', (, , text) !->
						t.equal(text, plaintext, 'Correct text message received in text_message event on node 1')
					)
					.on('custom_command', (, command, data) !->
						t.equal(command, 99, 'Custom command received correctly on node 1')
						t.equal(Buffer.from(data).toString(), plaintext, 'Custom command data received correctly on node 1')

						chat_node_1.destroy()
						chat_node_3.destroy()
						destroy_nodes()
					)
				chat_node_3
					.on('connected', !->
						t.pass('Connected successfully')

						chat_node_3.secret(node_1_real_public_key, generated_secret)
					)
					.on('connection_failed', (, reason) !->
						t.fail('Connection failed with code ' + reason)

						chat_node_1.destroy()
						chat_node_3.destroy()
						destroy_nodes()
					)
					.on('secret_received', !->
						t.pass('Secret received on node 3')
					)
					.on('secret', (, secret) !->
						t.equal(secret.join(','), generated_secret.join(','), 'Correct secret received in secret event on node 3')

						chat_node_3
							..nickname(node_1_real_public_key, 'Node 3')
							..text_message(node_1_real_public_key, plaintext)
					)
					.on('text_message_received', !->
						t.pass('Text message received on node 3')

						chat_node_3.custom_command(node_1_real_public_key, 99, Buffer.from(plaintext))
					)

				chat_node_3.connect_to(node_1_real_public_key, generated_secret)
			), 5000
		)

		console.log 'Preparing for announcement (2s)...'
		setTimeout (!->
			console.log 'Announcing node 1...'
			chat_node_1.announce()
		), 2000
)

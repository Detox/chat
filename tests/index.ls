/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
require('@detox/simple-peer-mock').register()

detox-core		= require('@detox/core')
detox-crypto	= require('@detox/crypto')
detox-utils		= require('@detox/utils')
lib				= require('..')
test			= require('tape')

const NUMBER_OF_NODES		= 50
const bootstrap_node_id		= '3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29'
const bootstrap_ip			= '127.0.0.1'
const bootstrap_port		= 16882
const bootstrap_node_info	= "#bootstrap_node_id:#bootstrap_ip:#bootstrap_port"
const plaintext				= 'Hello, Detox chat!'

const expected_public_key	= Buffer.from('09d174678b66eeebbd7f4fa4a427adc7c3aa172703b8c4844344f168f0e2c6eb', 'hex')
const expected_secret		= Buffer.from('0a3b582115fd9be7b581a3282b587a8b27d8087f30e602328253abcd552d3291', 'hex')
const expected_id			= '4poWr1r1hnXUjo7ED7T1R2gU9wfeBxkAfX8fcnMYQe2QyXT9BC3wMKB1MqE6bNBHBCy6BqzZoMhdLaNjfNoQnVAkSA'

const expected_bootstrap_node	= '2UGPcWBEr2RQonHUscd21CkFtaoJ18xJdEuWFAhDyZMY2RzE7bzcbvR6gQhHH4'

<-! lib.ready
test('Core', (t) !->
	generated_seed	= lib.generate_seed()
	t.ok(generated_seed instanceof Uint8Array, 'Seed is Uint8Array')
	t.equal(generated_seed.length, 32, 'Seed length is 32 bytes')

	generated_secret	= lib.generate_secret()
	t.ok(generated_secret instanceof Uint8Array, 'Secret is Uint8Array')
	t.equal(generated_secret.length, 32, 'Secret length is 32 bytes')

	t.equal(lib.id_encode(expected_public_key, expected_secret), expected_id, 'Encoded ID correctly')
	t.equal(detox-utils.concat_arrays(lib.id_decode(expected_id)).join(','), detox-utils.concat_arrays([expected_public_key, expected_secret]).join(','), 'Decoded ID correctly')

	node_1_real_seed		= new Uint8Array(32)
		..set([1, 1])
	node_1_real_public_key	= detox-crypto.create_keypair(node_1_real_seed).ed25519.public
	node_3_real_seed		= new Uint8Array(32)
		..set([3, 1])
	node_3_real_public_key	= detox-crypto.create_keypair(node_3_real_seed).ed25519.public

	nodes	= []

	wait_for	= NUMBER_OF_NODES
	options		=
		timeouts				:
			STATE_UPDATE_INTERVAL				: 2
			GET_MORE_AWARE_OF_NODES_INTERVAL	: 2
			ROUTING_PATH_SEGMENT_TIMEOUT		: 30
			LAST_USED_TIMEOUT					: 15
			ANNOUNCE_INTERVAL					: 5
			RANDOM_LOOKUPS_INTERVAL				: 100
		connected_nodes_limit	: 30
		lookup_number			: 3
	promise		= Promise.resolve()
	for let i from 0 til NUMBER_OF_NODES
		promise		:= promise.then ->
			new Promise (resolve) !->
				dht_seed	= new Uint8Array(32)
					..set([i])
				if i == 0
					instance	= detox-core.Core([], [], 5, 1, Object.assign({}, options, {dht_keypair_seed : dht_seed, connected_nodes_limit : NUMBER_OF_NODES}))
					instance.start_bootstrap_node(dht_seed, bootstrap_ip, bootstrap_port)
				else
					instance	= detox-core.Core([bootstrap_node_info], [], 5, 1, Object.assign({dht_keypair_seed : dht_seed}, options))
				instance.once('ready', !->
					t.pass('Node ' + i + ' is ready, #' + (NUMBER_OF_NODES - wait_for + 1) + '/' + NUMBER_OF_NODES)

					--wait_for
					if !wait_for
						ready_callback()
				)
				nodes.push(instance)
				setTimeout(resolve, 100)

	!function destroy_nodes
		console.log 'Destroying nodes...'
		for node in nodes
			node.destroy()
		console.log 'Destroyed'
		t.end()

	!function ready_callback
		announcement_retry	= 3
		connection_retry	= 5
		node_1				= nodes[1]
		node_3				= nodes[3]

		chat_node_1	= lib.Chat(node_1, node_1_real_seed, 1, 1)
		chat_node_3	= lib.Chat(node_3, node_3_real_seed, 1, 1)

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
					.on('text_message', (, , , text) !->
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
						if connection_retry
							--connection_retry
							console.log 'Connection failed with code ' + reason + ', retry in 5s...'
							setTimeout (!->
								console.log 'Connecting...'
								node_3.connect_to(node_3_real_seed, node_1_real_public_key, application, node_1_secret, 1)
							), 5000
							return
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
							..text_message(node_1_real_public_key, +(new Date), plaintext)
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

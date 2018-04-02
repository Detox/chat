// Generated by LiveScript 1.5.0
/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
(function(){
  var detoxCore, detoxCrypto, detoxUtils, lib, test, NUMBER_OF_NODES, bootstrap_node_id, bootstrap_ip, bootstrap_port, bootstrap_node_info, plaintext, expected_public_key, expected_secret, expected_id, expected_bootstrap_node;
  detoxCore = require('@detox/core');
  detoxCrypto = require('@detox/crypto');
  detoxUtils = require('@detox/utils');
  lib = require('..');
  test = require('tape');
  NUMBER_OF_NODES = 18;
  bootstrap_node_id = '3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29';
  bootstrap_ip = '127.0.0.1';
  bootstrap_port = 16882;
  bootstrap_node_info = {
    node_id: bootstrap_node_id,
    host: bootstrap_ip,
    port: bootstrap_port
  };
  plaintext = 'Hello, Detox chat!';
  expected_public_key = Buffer.from('09d174678b66eeebbd7f4fa4a427adc7c3aa172703b8c4844344f168f0e2c6eb', 'hex');
  expected_secret = Buffer.from('0a3b582115fd9be7b581a3282b587a8b27d8087f30e602328253abcd552d3291', 'hex');
  expected_id = '4poWr1r1hnXUjo7ED7T1R2gU9wfeBxkAfX8fcnMYQe2QyXT9BC3wMKB1MqE6bNBHBCy6BqzZoMhdLaNjfNoQnVAnVC';
  expected_bootstrap_node = '2UGPcWBEr2RQonHUscd21CkFtaoJ18xJdEuWFAhDyZMY2RzE7bzcbvR6gQhDkc';
  lib.ready(function(){
    test('Core', function(t){
      var generated_seed, generated_secret, x$, node_1_real_seed, node_1_real_public_key, y$, node_3_real_seed, node_3_real_public_key, nodes, wait_for, i$, to$;
      t.plan(NUMBER_OF_NODES + 22);
      generated_seed = lib.generate_seed();
      t.ok(generated_seed instanceof Uint8Array, 'Seed is Uint8Array');
      t.equal(generated_seed.length, 32, 'Seed length is 32 bytes');
      generated_secret = lib.generate_secret();
      t.ok(generated_secret instanceof Uint8Array, 'Secret is Uint8Array');
      t.equal(generated_secret.length, 32, 'Secret length is 32 bytes');
      t.equal(lib.id_encode(expected_public_key, expected_secret), expected_id, 'Encoded ID correctly');
      t.equal(detoxUtils.concat_arrays(lib.id_decode(expected_id)).join(','), detoxUtils.concat_arrays([expected_public_key, expected_secret]).join(','), 'Decoded ID correctly');
      t.equal(lib.bootstrap_node_encode(bootstrap_node_id, bootstrap_ip, bootstrap_port), expected_bootstrap_node, 'Encoded bootstrap node correctly');
      t.equal(lib.bootstrap_node_decode(expected_bootstrap_node).join(','), [bootstrap_node_id, bootstrap_ip, bootstrap_port].join(','), 'Decoded bootstrap node correctly');
      x$ = node_1_real_seed = new Uint8Array(32);
      x$.set([1, 1]);
      node_1_real_public_key = detoxCrypto.create_keypair(node_1_real_seed).ed25519['public'];
      y$ = node_3_real_seed = new Uint8Array(32);
      y$.set([3, 1]);
      node_3_real_public_key = detoxCrypto.create_keypair(node_3_real_seed).ed25519['public'];
      nodes = [];
      wait_for = NUMBER_OF_NODES;
      for (i$ = 0, to$ = NUMBER_OF_NODES; i$ < to$; ++i$) {
        (fn$.call(this, i$));
      }
      function destroy_nodes(){
        var i$, ref$, len$, node;
        console.log('Destroying nodes...');
        for (i$ = 0, len$ = (ref$ = nodes).length; i$ < len$; ++i$) {
          node = ref$[i$];
          node.destroy();
        }
        console.log('Destroyed');
      }
      function ready_callback(){
        var node_1, node_3, chat_node_1, chat_node_3;
        node_1 = nodes[1];
        node_3 = nodes[3];
        chat_node_1 = lib.Chat(node_1, node_1_real_seed, 2, 1);
        chat_node_3 = lib.Chat(node_3, node_3_real_seed, 2, 1);
        t.deepEqual(node_1.get_bootstrap_nodes()[0], bootstrap_node_info, 'Bootstrap nodes are returned correctly');
        t.equal(node_1.get_max_data_size(), Math.pow(2, 16) - 1, 'Max data size returned correctly');
        chat_node_1.once('announced', function(){
          t.pass('Node 1 announced successfully');
          console.log('Preparing for connection (5s)...');
          setTimeout(function(){
            console.log('Connecting...');
            chat_node_1.on('introduction', function(arg$, secret){
              t.equal(secret.join(','), generated_secret.join(','), 'Correct secret received on introduction');
            }).on('secret', function(arg$, secret){
              t.equal(secret.join(','), generated_secret.join(','), 'Correct secret received in secret event on node 1');
              chat_node_1.secret(node_3_real_public_key, generated_secret);
            }).on('secret_received', function(){
              t.pass('Secret received on node 1');
            }).on('nickname', function(arg$, nickname){
              t.equal(nickname, 'Node 3', 'Correct nickname received on node 1');
            }).on('text_message', function(arg$, arg1$, arg2$, text){
              t.equal(text, plaintext, 'Correct text message received in text_message event on node 1');
            }).on('custom_command', function(arg$, command, data){
              t.equal(command, 99, 'Custom command received correctly on node 1');
              t.equal(Buffer.from(data).toString(), plaintext, 'Custom command data received correctly on node 1');
              chat_node_1.destroy();
              chat_node_3.destroy();
              destroy_nodes();
            });
            chat_node_3.on('connected', function(){
              t.pass('Connected successfully');
              chat_node_3.secret(node_1_real_public_key, generated_secret);
            }).on('connection_failed', function(arg$, reason){
              t.fail('Connection failed with code ' + reason);
              chat_node_1.destroy();
              chat_node_3.destroy();
              destroy_nodes();
            }).on('secret_received', function(){
              t.pass('Secret received on node 3');
            }).on('secret', function(arg$, secret){
              var x$;
              t.equal(secret.join(','), generated_secret.join(','), 'Correct secret received in secret event on node 3');
              x$ = chat_node_3;
              x$.nickname(node_1_real_public_key, 'Node 3');
              x$.text_message(node_1_real_public_key, +new Date, plaintext);
            }).on('text_message_received', function(){
              t.pass('Text message received on node 3');
              chat_node_3.custom_command(node_1_real_public_key, 99, Buffer.from(plaintext));
            });
            chat_node_3.connect_to(node_1_real_public_key, generated_secret);
          }, 5000);
        });
        console.log('Preparing for announcement (2s)...');
        setTimeout(function(){
          console.log('Announcing node 1...');
          chat_node_1.announce();
        }, 2000);
      }
      function fn$(i){
        var x$, dht_seed, instance;
        x$ = dht_seed = new Uint8Array(32);
        x$.set([i]);
        if (i === 0) {
          instance = detoxCore.Core(dht_seed, [], [], 5, 5);
          instance.start_bootstrap_node(bootstrap_ip, bootstrap_port);
        } else {
          instance = detoxCore.Core(dht_seed, [bootstrap_node_info], [], 5);
        }
        instance.once('ready', function(){
          t.pass('Node ' + i + ' is ready, #' + (NUMBER_OF_NODES - wait_for + 1) + '/' + NUMBER_OF_NODES);
          --wait_for;
          if (!wait_for) {
            ready_callback();
          }
        });
        nodes.push(instance);
      }
    });
  });
}).call(this);

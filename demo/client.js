// Generated by LiveScript 1.5.0
/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
(function(){
  var NUMBER_OF_NODES, bootstrap_node_id, bootstrap_ip, bootstrap_port, bootstrap_node_info;
  requirejs.config({
    baseUrl: '/node_modules/',
    paths: {
      '@detox/base-x': '@detox/base-x/index',
      '@detox/chat': '/src/index',
      '@detox/core': '@detox/core/src/index',
      '@detox/crypto': '@detox/crypto/src/index',
      '@detox/dht': '@detox/dht/dist/detox-dht.browser',
      '@detox/transport': '@detox/transport/src/index',
      '@detox/utils': '@detox/utils/src/index',
      'async-eventer': 'async-eventer/src/index',
      'fixed-size-multiplexer': 'fixed-size-multiplexer/src/index',
      'pako': 'pako/dist/pako',
      'ronion': 'ronion/src/index',
      'simple-peer': 'simple-peer/simplepeer.min'
    },
    packages: [
      {
        name: 'aez.wasm',
        location: 'aez.wasm',
        main: 'src/index'
      }, {
        name: 'ed25519-to-x25519.wasm',
        location: 'ed25519-to-x25519.wasm',
        main: 'src/index'
      }, {
        name: 'noise-c.wasm',
        location: 'noise-c.wasm',
        main: 'src/index'
      }, {
        name: 'supercop.wasm',
        location: 'supercop.wasm',
        main: 'src/index'
      }
    ]
  });
  NUMBER_OF_NODES = 2;
  bootstrap_node_id = '3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29';
  bootstrap_ip = '127.0.0.1';
  bootstrap_port = 16882;
  bootstrap_node_info = {
    node_id: bootstrap_node_id,
    host: bootstrap_ip,
    port: bootstrap_port
  };
  require(['@detox/chat', '@detox/core', '@detox/crypto', '@detox/utils']).then(function(arg$){
    var detoxChat, detoxCore, detoxCrypto, detoxUtils;
    detoxChat = arg$[0], detoxCore = arg$[1], detoxCrypto = arg$[2], detoxUtils = arg$[3];
    detoxChat.ready(function(){
      var wait_for, i$, to$;
      window.nodes = [];
      wait_for = NUMBER_OF_NODES;
      function log(message){
        console.log(message);
        document.querySelector('#status').textContent = message;
      }
      for (i$ = 0, to$ = NUMBER_OF_NODES; i$ < to$; ++i$) {
        (fn$.call(this, i$));
      }
      function ready_callback(){
        var core_instance_0, core_instance_1, chat_seed_0, chat_seed_1, chat_keypair_0, chat_keypair_1, chat_instance_0, chat_instance_1;
        core_instance_0 = nodes[0];
        core_instance_1 = nodes[1];
        log('Creating chat instances...');
        chat_seed_0 = detoxUtils.random_bytes(32);
        chat_seed_1 = detoxUtils.random_bytes(32);
        chat_keypair_0 = detoxCrypto.create_keypair(chat_seed_0);
        chat_keypair_1 = detoxCrypto.create_keypair(chat_seed_1);
        chat_instance_0 = detoxChat.Chat(core_instance_0, chat_seed_0);
        chat_instance_1 = detoxChat.Chat(core_instance_1, chat_seed_1);
        window.chat_nodes = [chat_instance_0, chat_instance_1];
        window.chat_opponents = [chat_keypair_1.ed25519['public'], chat_keypair_0.ed25519['public']];
        detoxUtils.timeoutSet(2, function(){
          var i$, ref$, len$;
          log('Announcing node 1 to the network...');
          chat_instance_1.on('announced', function(){
            log('Announced, connecting from node 0 to node 1...');
            chat_instance_0.on('connected', function(){
              var wait_for, x$, y$;
              log('Connected, updating secrets...');
              wait_for = 4;
              function ready(){
                --wait_for;
                if (!wait_for) {
                  log('Connected, you can chat now!');
                }
              }
              x$ = chat_instance_0;
              x$.secret(chat_keypair_1.ed25519['public'], new Uint8Array(32));
              x$.on('secret', ready);
              x$.on('secret_received', ready);
              y$ = chat_instance_1;
              y$.secret(chat_keypair_0.ed25519['public'], new Uint8Array(32));
              y$.on('secret', ready);
              y$.on('secret_received', ready);
            }).on('connection_failed', function(arg$, reason){
              log("Connection failed, reason code " + reason + ", trying again in 1s");
              detoxUtils.timeoutSet(1, function(){
                chat_instance_0.connect_to(chat_keypair_1.ed25519['public'], new Uint8Array(0));
              });
            });
            chat_instance_0.connect_to(chat_keypair_1.ed25519['public'], new Uint8Array(0));
          });
          chat_instance_1.announce();
          for (i$ = 0, len$ = (ref$ = Array.from(document.querySelectorAll('.chat'))).length; i$ < len$; ++i$) {
            (fn$.call(this, i$, ref$[i$]));
          }
          function fn$(index, chat_element){
            var textarea, messages, chat_node, chat_opponent;
            textarea = chat_element.querySelector('textarea');
            messages = chat_element.querySelector('div');
            chat_node = chat_nodes[index];
            chat_opponent = chat_opponents[index];
            chat_element.querySelector('button').addEventListener('click', function(){
              var x$;
              chat_node.text_message(chat_opponent, textarea.value);
              messages.prepend((x$ = document.createElement('div'), x$.textContent = textarea.value, x$.classList.add('right'), x$));
              textarea.value = '';
            });
            chat_node.on('text_message', function(arg$, arg1$, message){
              var x$;
              messages.prepend((x$ = document.createElement('div'), x$.textContent = message, x$));
            });
          }
        });
      }
      function fn$(i){
        var instance;
        instance = detoxCore.Core(detoxChat.generate_seed(), [bootstrap_node_info], [], 5);
        instance.once('ready', function(){
          log('Node ' + i + ' is ready, #' + (NUMBER_OF_NODES - wait_for + 1) + '/' + NUMBER_OF_NODES);
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

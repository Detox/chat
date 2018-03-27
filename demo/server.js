// Generated by LiveScript 1.5.0
/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
(function(){
  var detoxCore, NUMBER_OF_NODES, bootstrap_node_id, bootstrap_ip, bootstrap_port, bootstrap_node_info;
  detoxCore = require('@detox/core');
  NUMBER_OF_NODES = 10;
  bootstrap_node_id = '3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29';
  bootstrap_ip = '127.0.0.1';
  bootstrap_port = 16882;
  bootstrap_node_info = {
    node_id: bootstrap_node_id,
    host: bootstrap_ip,
    port: bootstrap_port
  };
  detoxCore.ready(function(){
    var nodes, wait_for, i$, to$;
    nodes = [];
    wait_for = NUMBER_OF_NODES;
    for (i$ = 0, to$ = NUMBER_OF_NODES; i$ < to$; ++i$) {
      (fn$.call(this, i$));
    }
    function ready_callback(){
      console.log("All nodes are ready, connect to bootstrap node at " + bootstrap_ip + ":" + bootstrap_port + " with ID " + bootstrap_node_id);
    }
    function fn$(i){
      var instance;
      if (i === 0) {
        instance = detoxCore.Core(new Uint8Array(32), [], [], 5, 10);
        instance.start_bootstrap_node(bootstrap_ip, bootstrap_port);
      } else {
        instance = detoxCore.Core(detoxCore.generate_seed(), [bootstrap_node_info], [], 5);
      }
      instance.once('ready', function(){
        console.log('Node ' + i + ' is ready, #' + (NUMBER_OF_NODES - wait_for + 1) + '/' + NUMBER_OF_NODES);
        --wait_for;
        if (!wait_for) {
          ready_callback();
        }
      });
      nodes.push(instance);
    }
  });
}).call(this);

## Here's a basic example of how you would start a Waku node, subscribe to
## topics, and publish to them.

import
  std/[os,options],
  confutils, chronicles, chronos,
  stew/shims/net as stewNet,
  stew/byteutils,
  libp2p/crypto/[crypto,secp],
  eth/keys,
  json_rpc/[rpcclient, rpcserver],
  ../../waku/v2/node/waku_node,
  ../../apps/wakunode2/config,
  ../../waku/common/utils/nat,
  ../../waku/v2/protocol/waku_message

# Node operations happens asynchronously
proc runBackground() {.async.} =
  let
    conf = WakuNodeConf.load().tryGet()
    (extIp, extTcpPort, extUdpPort) = setupNat(conf.nat, clientId,
      Port(uint16(conf.tcpPort) + conf.portsShift),
      # This is actually a UDP port but we're only supplying this value
      # To satisfy the API.
      Port(uint16(conf.tcpPort) + conf.portsShift))
    node = WakuNode.new(conf.nodeKey, conf.listenAddress,
      Port(uint16(conf.tcpPort) + conf.portsShift), extIp, extTcpPort)

  await node.start()
  await node.mountRelay()

  # Subscribe to a topic
  let topic = PubsubTopic("foobar")
  proc handler(topic: PubsubTopic, data: seq[byte]) {.async, gcsafe.} =
    let message = WakuMessage.decode(data).value
    let payload = cast[string](message.payload)
    info "Hit subscribe handler", topic=topic, payload=payload, contentTopic=message.contentTopic
  node.subscribe(topic, handler)

  # Publish to a topic
  let payload = toBytes("hello world")
  let message = WakuMessage(payload: payload, contentTopic: ContentTopic("/waku/2/default-content/proto"))
  await node.publish(topic, message)

# TODO Await with try/except here
discard runBackground()

runForever()

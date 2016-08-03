###
  Pokemon Go (c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>
###

Proxy = require 'http-mitm-proxy'
POGOProtos = require 'pokemongo-protobuf'
changeCase = require 'change-case'
https = require 'https'
fs = require 'fs'
_ = require 'lodash'
request = require 'request'
rp = require 'request-promise'
Promise = require 'bluebird'
DNS = require 'dns'

class PokemonGoMITM
  endpoint: 'pgorelease.nianticlabs.com'
  endpointIPs: []

  responseEnvelope: 'POGOProtos.Networking.Envelopes.ResponseEnvelope'
  requestEnvelope: 'POGOProtos.Networking.Envelopes.RequestEnvelope'

  requestHandlers: {}
  responseHandlers: {}
  requestEnvelopeHandlers: []
  responseEnvelopeHandlers: []

  requestInjectQueue: []
  lastRequest: null
  lastCtx: null

  proxy: null

  constructor: (options) ->
    @port = options.port or 8081
    @debug = options.debug or false
    @setupProxy()

  close: ->
    console.log "[+] Stopping MITM Proxy..."
    @proxy.close()

  setupProxy: ->
    @proxy = new Proxy()
      .use Proxy.gunzip
      .onConnect @handleProxyConnect
      .onRequest @handleProxyRequest
      .onError @handleProxyError
      .listen port: @port

    @proxy.silent = true

    console.log "[+++] PokemonGo MITM Proxy listening on #{@port}"
    console.log "[!] Make sure to have the CA cert .http-mitm-proxy/certs/ca.pem installed on your device"

  handleProxyConnect: (req, socket, head, callback) =>
    @log("#{req.method} #{req.url}")

    if req.url.match /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:443/
      ip = req.url.split(/:/)[0]

      if @endpointIPs.length
        req.url = @endpoint+':443' if ip in @endpointIPs
        callback()

      else
        DNS.resolve @endpoint, "A", (err, addresses) =>
          @endpointIPs = addresses
          req.url = @endpoint+':443' if ip in addresses
          callback()
    else
      callback()

  handleProxyRequest: (ctx, callback) =>
    @logCtxURL @fullCtxURL(ctx)

    # don't interfer with anything not going to the Pokemon API
    return callback() unless ctx.clientToProxyRequest.headers.host is @endpoint

    @log "[+++] Request to #{ctx.clientToProxyRequest.url}"

    ### Client Reuqest Handling ###
    requested = []
    requestChunks = []
    injected = 0
    ctx.onRequestData (ctx, chunk, callback) =>
      requestChunks.push chunk
      callback null,null

    ctx.onRequestEnd (ctx, callback) =>
      buffer = Buffer.concat requestChunks
      try
        data = POGOProtos.parse buffer, @requestEnvelope
      catch e
        @log "[-] Parsing protobuf of RequestEnvelope failed.."
        ctx.proxyToServerRequest.write buffer
        return callback()

      @lastRequest = data
      @lastCtx = ctx

      originalData = _.cloneDeep data

      for handler in @requestEnvelopeHandlers
        data = handler(data, url: ctx.clientToProxyRequest.url) or data

      for id,request of data.requests
        protoId = changeCase.pascalCase request.request_type

        # Queue the ProtoId for the response handling
        requested.push "POGOProtos.Networking.Responses.#{protoId}Response"

        proto = "POGOProtos.Networking.Requests.Messages.#{protoId}Message"
        unless proto in POGOProtos.info()
          @log "[-] Request handler for #{protoId} isn't implemented yet.."
          continue

        try
          decoded = if request.request_message
            POGOProtos.parse request.request_message, proto
          else {}
        catch e
          @log "[-] Parsing protobuf of #{protoId} failed.."
          continue

        originalRequest = _.cloneDeep decoded
        afterHandlers = @handleRequest protoId, decoded

        unless _.isEqual originalRequest, afterHandlers
          @log "[!] Overwriting "+protoId
          request.request_message = POGOProtos.serialize afterHandlers, proto

      for request in @requestInjectQueue
        unless data.requests.length < 5
          @log "[-] Delaying inject of #{request.action} because RequestEnvelope is full"
          break

        @log "[+] Injecting request to #{request.action}"
        injected++

        requested.push "POGOProtos.Networking.Responses.#{request.action}Response"
        data.requests.push
          request_type: changeCase.constantCase request.action
          request_message: POGOProtos.serialize request.data, "POGOProtos.Networking.Requests.Messages.#{request.action}Message"

      @requestInjectQueue = @requestInjectQueue.slice injected

      unless _.isEqual originalData, data
        @log "[+] Recoding RequestEnvelope"
        buffer = POGOProtos.serialize data, @requestEnvelope

      ctx.proxyToServerRequest.write buffer

      @log "[+] Waiting for response..."
      callback()

    ### Server Response Handling ###
    responseChunks = []
    ctx.onResponseData (ctx, chunk, callback) =>
      responseChunks.push chunk
      callback()

    ctx.onResponseEnd (ctx, callback) =>
      buffer = Buffer.concat responseChunks
      try
        data = POGOProtos.parse buffer, @responseEnvelope
      catch e
        @log "[-] Parsing protobuf of ResponseEnvelope failed: #{e}"
        ctx.proxyToClientResponse.end buffer
        return callback()

      originalData = _.cloneDeep data

      for handler in @responseEnvelopeHandlers
        data = handler(data, {}) or data

      for id,response of data.returns
        proto = requested[id]
        if proto in POGOProtos.info()
          decoded = POGOProtos.parse response, proto

          protoId = proto.split(/\./).pop().split(/Response/)[0]

          originalResponse = _.cloneDeep decoded
          afterHandlers = @handleResponse protoId, decoded
          unless _.isEqual afterHandlers, originalResponse
            @log "[!] Overwriting "+protoId
            data.returns[id] = POGOProtos.serialize afterHandlers, proto

          if injected and data.returns.length-injected-1 >= id
            # Remove a previously injected request to not confuse the client
            @log "[!] Removing #{protoId} from response as it was previously injected"
            delete data.returns[id]

        else
          @log "[-] Response handler for #{requested[id]} isn't implemented yet.."

      # Overwrite the response in case a hook hit the fan
      unless _.isEqual originalData, data
        buffer = POGOProtos.serialize data, @responseEnvelope

      ctx.proxyToClientResponse.end buffer
      callback false

    callback()

  handleProxyError: (ctx, err, errorKind) =>
    url = if ctx and ctx.clientToProxyRequest then ctx.clientToProxyRequest.url else ''
    @log '[-] ' + errorKind + ' on ' + url + ':', err

  handleRequest: (action, data) ->
    @log "[+] Request for action #{action}: "
    @log data if data

    handlers = [].concat @requestHandlers[action] or [], @requestHandlers['*'] or []
    for handler in handlers
      data = handler(data, action) or data

    data

  handleResponse: (action, data) ->
    @log "[+] Response for action #{action}"
    @log data if data

    handlers = [].concat @responseHandlers[action] or [], @responseHandlers['*'] or []
    for handler in handlers
      data = handler(data, action) or data

    data

  injectRequest: (action, data) ->
    unless "POGOProtos.Networking.Requests.Messages.#{action}Message" in POGOProtos.info()
      @log "[-] Can't inject request #{action} - proto not implemented"
      return

    @requestInjectQueue.push
      action: action
      data: data

  craftRequest: (action, data, requestEnvelope=@lastRequest, url=undefined) ->
    @log "[+] Crafting request for #{action}"

    requestEnvelope.request_id ?= 1000000000000000000-Math.floor(Math.random()*1000000000000000000)

    requestEnvelope.requests = [
      request_type: changeCase.constantCase action
      request_message: POGOProtos.serialize data, "POGOProtos.Networking.Requests.Messages.#{changeCase.pascalCase action}Message"
    ]

    _.defaults requestEnvelope, @lastRequest

    buffer = POGOProtos.serialize requestEnvelope, 'POGOProtos.Networking.Envelopes.RequestEnvelope'
    url ?= 'https://' + @lastCtx.clientToProxyRequest.headers.host + '/' + @lastCtx.clientToProxyRequest.url

    return rp(
      hostname: @lastCtx.clientToProxyRequest.headers.host
      url: url
      method: 'POST'
      body: buffer
      encoding: null
      headers:
        'Content-Type': 'application/x-www-form-urlencoded'
        'Content-Length': Buffer.byteLength buffer
        'Connection': 'Close'
        'User-Agent': @lastCtx?.clientToProxyRequest?.headers['user-agent']
      ).then((buffer) =>
        try
          @log "[+] Response for crafted #{action}"

          decoded = POGOProtos.parse buffer, "POGOProtos.Networking.Envelopes.ResponseEnvelope"
          data = POGOProtos.parse decoded.returns[0], "POGOProtos.Networking.Responses.#{changeCase.pascalCase action}Response"

          @log data
          data
        catch e
          @log "[-] Parsing of response to crafted #{action} failed: #{e}"
          throw e
      ).catch (e) =>
        @log "[-] Crafting a request failed with #{e}"
        throw e

  setResponseHandler: (action, cb) ->
    @addResponseHandler action, cb
    this

  addResponseHandler: (action, cb) ->
    @responseHandlers[action] ?= []
    @responseHandlers[action].push(cb)
    this

  setRequestHandler: (action, cb) ->
    @addRequestHandler action, cb
    this

  addRequestHandler: (action, cb) ->
    @requestHandlers[action] ?= []
    @requestHandlers[action].push(cb)
    this

  addRequestEnvelopeHandler: (cb, name=undefined) ->
    @requestEnvelopeHandlers.push cb
    this

  addResponseEnvelopeHandler: (cb, name=undefined) ->
    @responseEnvelopeHandlers.push cb
    this

  log: (text) ->
    console.log text if @debug

  logCtxURL: (ctx) ->
    if @debug
      opts = ctx.proxyToServerRequestOptions
      portString = if opts.port then ":#{opts.port}" else ''
      console.log("#{opts.method} #{opts.host}#{portString}#{opts.path}")

module.exports = PokemonGoMITM

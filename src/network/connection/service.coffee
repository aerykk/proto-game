require('../../buffer')
network = require('../__init__')
base = require('../service').service

class service extends base
	constructor: () ->
		super()
		
		@request_handlers =
			1: network.connection.echo_request
			2: network.connection.disconnect_notification
			3: network.connection.null_request
			4: network.connection.encrypt_request
			5: network.connection.disconnect_request
		
		@response_handlers =
			1: network.connection.echo_response
			2: network.connection.null_response
			3: network.connection.encrypt_response
			4: network.connection.disconnect_response
		
	
	send: (params) ->
		service_id = @id
		request_id = ++@total_requests
		m1 = params.message.pack()
		m2 = new Buffer()
		m2[0] = service_id #m2.writeUInt8(service_id, 0)
		m2[1] = params.method_id #m2.writeUInt8(params.method_id, 1)
		#m2.writeUInt16(request_id, 2) # unknown
		m2[4] = m1.length #m2.writeUInt8(m1.length, 4)
		
		m1.copy(m2, 6)
		
		console.log 'Sending: ', ' Service: ', service_id, ' Method: ', params.method_id, ' Length: ', m1.length, ' Message: ', m1
		
		if params.call
			@request_callbacks[request_id] = params.call
		
		params.endpoint.write(m2)
	
	receive: (params) ->
		result =
			endpoint: params.endpoint
			method_id: params.message[0] #method_id: params.message.readUInt8(0)
			request_id: params.message[1] #request_id: params.message.readUInt8(1)
			#unknown: params.message.readRawVarint8(2)
			length: params.message[4] + (params.message[3] << 16) #length: params.message.readRawVarint16(3) 
			message: params.message.slice(5)
		
		console.log 'Received: ', 'Method: ', result.method_id, 'Unknown: ', result.unknown, 'Length: ', result.length, 'Message: ', result.message
		
		if !@request_handlers[result.method_id]
			console.log "Cannot find a request handler."
			
		if @request_callbacks[result.request_id]
			result.message = new @response_handlers[result.method_id]().unpack(result.message)
			call = @request_callbacks[result.request_id]
			
			delete @request_callbacks[result.request_id]
			
			call(result)
		else
			result.message = new @request_handlers[result.method_id]().unpack(result.message)
		
			@emit(result.message.name.replace('network.connection.', ''), result)

	id: 3
	hash: 0xb732db32
	name: 'connection'
	request_callbacks: {}
	total_requests: 0
	request_handlers: {}
	response_handlers: {}

exports.service = service
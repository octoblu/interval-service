request       = require 'request'
mongojs       = require 'mongojs'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
moment        = require 'moment'
Server        = require '../../src/server'

describe 'Fire Once Register Message', ->
  beforeEach (done) ->
    @meshblu = shmock 0xd00d
    enableDestroy @meshblu

    serverOptions =
      port: undefined,
      disableLogging: true
      meshbluConfig:
        hostname: 'localhost'
        port: 0xd00d
        protocol: 'http'
      publicKey:
        publicKey: null
      mongodbUri: 'interval-service-test'
      intervalServiceUri: 'http://interval-service.octoblu.test'

    @server = new Server serverOptions

    @server.run =>
      @serverPort = @server.address().port
      done()

  beforeEach (done) ->
    @db = mongojs 'interval-service-test', ['soldiers']
    @db.soldiers.remove done
    @datastore = @db.soldiers

  afterEach (done) ->
    @meshblu.destroy()
    @server.stop done

  context 'On POST /message', ->
    describe 'with no previous instances exists', ->
      beforeEach (done) ->
        record =
          metadata:
            ownerUuid   : 'some-flow-uuid'
            nodeId      : 'some-interval-node'
            intervalUuid: 'interval-device-uuid'
            credentialsOnly: true
          data:
            uuid: 'interval-device-uuid'
            token: 'interval-device-token'
            nodeId: 'some-interval-node'
        @datastore.insert record, done

      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'

        @authDevice = @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 200, uuid: 'some-uuid', token: 'some-token'

        options =
          uri: '/message'
          baseUrl: "http://localhost:#{@serverPort}"
          auth:
            username: 'some-uuid'
            password: 'some-token'
          json: true
          body:
            topic: 'register-interval'
            payload:
              nodeId: 'some-interval-node'
              transactionId: 'some-transaction-id'
              sendTo: 'some-flow-uuid'
              nonce: 'this-is-nonce-once'
              intervalTime: 10000
              fireOnce: true

        request.post options, (error, @response, @body) =>
          @processAt = moment().unix()
          done error

      it 'should return a 201', ->
        expect(@response.statusCode).to.equal 201

      it 'should auth handler', ->
        @authDevice.done()

      it 'should keep the main record in mongo', (done) ->
        query =
          'metadata.ownerUuid': 'some-flow-uuid'
          'metadata.nodeId'   : 'some-interval-node'
          'metadata.credentialsOnly': true
        @datastore.findOne query, {_id: false}, (error, record) =>
          return done error if error?
          expectedRecord =
            metadata:
              ownerUuid   : 'some-flow-uuid'
              intervalUuid: 'interval-device-uuid'
              nodeId      : 'some-interval-node'
              credentialsOnly: true
            data:
              uuid: 'interval-device-uuid'
              token: 'interval-device-token'
              nodeId: 'some-interval-node'
          expect(record.uuid).to.not.exist
          expect(record.metadata).to.deep.equal expectedRecord.metadata
          expect(record.data).to.deep.equal expectedRecord.data
          done()

      it 'should keep the transaction record in mongo', (done) ->
        query =
          'metadata.ownerUuid'    : 'some-flow-uuid'
          'metadata.nodeId'       : 'some-interval-node'
          'metadata.transactionId': 'some-transaction-id'
          'metadata.credentialsOnly': false
        @datastore.findOne query, {_id: false}, (error, record) =>
          return done error if error?
          expectedRecord =
            metadata:
              ownerUuid: 'some-flow-uuid'
              transactionId: 'some-transaction-id'
              intervalUuid: 'interval-device-uuid'
              intervalTime: 10000
              nodeId: 'some-interval-node'
              nonce: 'this-is-nonce-once'
              lastRunAt: @processAt
              processNow: true
              fireOnce: true
              credentialsOnly: false
            data:
              fireOnce: true
              uuid: 'interval-device-uuid'
              token: 'interval-device-token'
              nodeId: 'some-interval-node'
              transactionId: 'some-transaction-id'
              sendTo: 'some-flow-uuid'
          expect(record.uuid).to.exist
          expect(record.metadata).to.deep.equal expectedRecord.metadata
          expect(record.data).to.deep.equal expectedRecord.data
          done()

    describe 'with multiple previous instances exists', ->
      beforeEach (done) ->
        record =
          uuid: 'credentials-uuid'
          metadata:
            ownerUuid   : 'some-flow-uuid'
            nodeId      : 'some-interval-node'
            intervalUuid: 'interval-device-uuid'
            credentialsOnly: true
          data:
            uuid: 'interval-device-uuid'
            token: 'interval-device-token'
            nodeId: 'some-interval-node'
        @datastore.insert record, done

      beforeEach (done) ->
        record =
          uuid: 'not-this'
          metadata:
            ownerUuid   : 'some-flow-uuid'
            nodeId      : 'some-interval-node'
            intervalUuid: 'interval-device-uuid'
            credentialsOnly: false
          data:
            uuid: 'interval-device-uuid'
            token: 'interval-device-token'
            nodeId: 'some-interval-node'
        @datastore.insert record, done

      beforeEach (done) ->
        record =
          uuid: 'definitely-not-this'
          metadata:
            ownerUuid   : 'some-flow-uuid'
            nodeId      : 'some-interval-node'
            intervalUuid: 'interval-device-uuid'
            credentialsOnly: false
          data:
            uuid: 'interval-device-uuid'
            token: 'interval-device-token'
            nodeId: 'some-interval-node'
        @datastore.insert record, done

      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'

        @authDevice = @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 200, uuid: 'some-uuid', token: 'some-token'

        options =
          uri: '/message'
          baseUrl: "http://localhost:#{@serverPort}"
          auth:
            username: 'some-uuid'
            password: 'some-token'
          json: true
          body:
            topic: 'register-interval'
            payload:
              nodeId: 'some-interval-node'
              transactionId: 'some-transaction-id'
              sendTo: 'some-flow-uuid'
              nonce: 'this-is-nonce-once'
              intervalTime: 10000
              fireOnce: true

        request.post options, (error, @response, @body) =>
          @processAt = moment().unix()
          done error

      it 'should return a 201', ->
        expect(@response.statusCode).to.equal 201

      it 'should auth handler', ->
        @authDevice.done()

      it 'should keep the credentials record in mongo', (done) ->
        query =
          'metadata.ownerUuid': 'some-flow-uuid'
          'metadata.nodeId'   : 'some-interval-node'
          'metadata.credentialsOnly': true
        @datastore.findOne query, {_id: false}, (error, record) =>
          return done error if error?
          expectedRecord =
            uuid: 'credentials-uuid'
            metadata:
              ownerUuid   : 'some-flow-uuid'
              intervalUuid: 'interval-device-uuid'
              nodeId      : 'some-interval-node'
              credentialsOnly: true
            data:
              uuid: 'interval-device-uuid'
              token: 'interval-device-token'
              nodeId: 'some-interval-node'
          expect(record.uuid).to.equal 'credentials-uuid'
          expect(record.metadata).to.deep.equal expectedRecord.metadata
          expect(record.data).to.deep.equal expectedRecord.data
          done()

      it 'should only have one transaction record', (done) ->
        query =
          'metadata.ownerUuid'    : 'some-flow-uuid'
          'metadata.nodeId'       : 'some-interval-node'
          'metadata.transactionId': 'some-transaction-id'
          'metadata.credentialsOnly': false
        @datastore.count query, (error, count) =>
          return done error if error?
          expect(count).to.equal 1
          done null

      it 'should keep the transaction record in mongo', (done) ->
        query =
          'metadata.ownerUuid'    : 'some-flow-uuid'
          'metadata.nodeId'       : 'some-interval-node'
          'metadata.transactionId': 'some-transaction-id'
          'metadata.credentialsOnly': false
        @datastore.findOne query, {_id: false}, (error, record) =>
          return done error if error?
          expectedRecord =
            metadata:
              ownerUuid: 'some-flow-uuid'
              transactionId: 'some-transaction-id'
              intervalUuid: 'interval-device-uuid'
              intervalTime: 10000
              nodeId: 'some-interval-node'
              nonce: 'this-is-nonce-once'
              lastRunAt: @processAt
              processNow: true
              fireOnce: true
              credentialsOnly: false
            data:
              fireOnce: true
              uuid: 'interval-device-uuid'
              token: 'interval-device-token'
              nodeId: 'some-interval-node'
              transactionId: 'some-transaction-id'
              sendTo: 'some-flow-uuid'
          expect(record.uuid).to.exist
          expect(record.uuid).to.not.equal 'not-this'
          expect(record.uuid).to.not.equal 'definitely-not-this'
          expect(record.metadata).to.deep.equal expectedRecord.metadata
          expect(record.data).to.deep.equal expectedRecord.data
          done()

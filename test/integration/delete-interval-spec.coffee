mongojs       = require 'mongojs'
request       = require 'request'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
Server        = require '../../src/server'

describe 'Delete Interval', ->
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
      mongodbUri: 'interval-service-test'
      client: {}
      publicKey:
        publicKey: null
      intervalServiceUri: 'http://interval-service.octoblu.test'

    @server = new Server serverOptions

    @server.run =>
      @serverPort = @server.address().port
      done()

  afterEach ->
    @meshblu.destroy()
    @server.destroy()

  beforeEach (done) ->
    @db = mongojs 'interval-service-test', ['soldiers']
    @db.soldiers.remove done
    @datastore = @db.soldiers

  describe 'On DELETE /nodes/:nodeId/destroy/:id', ->
    describe 'fresh test', ->
      beforeEach (done) ->
        data =
          metadata:
            ownerUuid: 'some-flow-uuid'
            intervalUuid: 'some-interval-uuid'
            nodeId   : 'node-uuid'
        @datastore.insert data, done

      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'

        @authDevice = @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 200, uuid: 'some-uuid', token: 'some-token'

        @deleteDevice = @meshblu
          .delete '/devices/some-interval-uuid'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 201

        options =
          uri: '/nodes/node-uuid/intervals/some-interval-uuid'
          baseUrl: "http://localhost:#{@serverPort}"
          auth:
            username: 'some-uuid'
            password: 'some-token'
          json:
            nodeId: 'node-uuid'

        request.delete options, (error, @response, @body) =>
          done error

      it 'should return a 200', ->
        expect(@response.statusCode).to.equal 200

      it 'should auth handler', ->
        @authDevice.done()

      it 'should delete the device', ->
        @deleteDevice.done()

      it 'should remove the mongodb entry', (done) ->
        @datastore.findOne 'metadata.intervalUuid': 'some-interval-uuid', (error, record) =>
          return done error if error?
          expect(record).not.to.exist
          done()

    describe 'when the two devices with the same intervalUuid exists', ->
      beforeEach (done) ->
        data =
          metadata:
            ownerUuid: 'some-uuid'
            intervalUuid: 'some-interval-uuid'
            nodeId   : 'node-uuid'
            credentialsOnly: true
        @datastore.insert data, done

      beforeEach (done) ->
        data =
          metadata:
            ownerUuid: 'some-uuid'
            intervalUuid: 'some-interval-uuid'
            nodeId   : 'node-uuid'
            credentialsOnly: false
        @datastore.insert data, done

      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'

        @authDevice = @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 200, uuid: 'some-uuid', token: 'some-token'

        @deleteDevice = @meshblu
          .delete '/devices/some-interval-uuid'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 201

        options =
          uri: '/nodes/node-uuid/intervals/some-interval-uuid'
          baseUrl: "http://localhost:#{@serverPort}"
          auth:
            username: 'some-uuid'
            password: 'some-token'
          json:
            nodeId: 'node-uuid'

        request.delete options, (error, @response, @body) =>
          done error

      it 'should return a 200', ->
        expect(@response.statusCode).to.equal 200

      it 'should auth handler', ->
        @authDevice.done()

      it 'should delete the device', ->
        @deleteDevice.done()

      it 'should have zero records with that intervalUuid', (done) ->
        @datastore.count 'metadata.intervalUuid': 'some-interval-uuid', (error, count) =>
          return done error if error?
          expect(count).to.equal 0
          done()

    describe 'when the three devices with the same intervalUuid exists', ->
      beforeEach (done) ->
        data =
          uuid: 'hi'
          metadata:
            ownerUuid: 'some-uuid'
            intervalUuid: 'some-interval-uuid'
            nodeId   : 'node-uuid'
            credentialsOnly: true
        @datastore.insert data, done

      beforeEach (done) ->
        data =
          uuid: 'hello'
          metadata:
            ownerUuid: 'some-uuid'
            intervalUuid: 'some-interval-uuid'
            nodeId   : 'node-uuid'
            credentialsOnly: false
        @datastore.insert data, done

      beforeEach (done) ->
        data =
          uuid: 'yay'
          metadata:
            ownerUuid: 'some-uuid'
            intervalUuid: 'some-interval-uuid'
            nodeId   : 'node-uuid'
            credentialsOnly: false
        @datastore.insert data, done

      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'

        @authDevice = @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 200, uuid: 'some-uuid', token: 'some-token'

        @deleteDevice = @meshblu
          .delete '/devices/some-interval-uuid'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 201

        options =
          uri: '/nodes/node-uuid/intervals/some-interval-uuid'
          baseUrl: "http://localhost:#{@serverPort}"
          auth:
            username: 'some-uuid'
            password: 'some-token'
          json:
            nodeId: 'node-uuid'

        request.delete options, (error, @response, @body) =>
          done error

      it 'should return a 200', ->
        expect(@response.statusCode).to.equal 200

      it 'should auth handler', ->
        @authDevice.done()

      it 'should delete the device', ->
        @deleteDevice.done()

      it 'should have zero records with that intervalUuid', (done) ->
        @datastore.count {'metadata.intervalUuid': 'some-interval-uuid'}, (error, count) =>
          return done error if error?
          expect(count).to.equal 0
          done()

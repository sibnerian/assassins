Game = new Mongo.Collection('Game')
window?.Game = Game

if Meteor.isServer
  Accounts.onCreateUser (options, user) ->
    if not user.services?.facebook?
      throw new Meteor.Error 500, 'You must log in with the face books!'
    if options.profile
      user.profile = options.profile
    user.isAdmin = (user.profile.name is Meteor.settings.adminName)
    user.index = -1
    user.target = -1
    user.targetName = ''
    user.alive = false
    user.secretPhrase = ''
    return user
  Meteor.publish 'Players', ->
    if Meteor.users.findOne(@userId)?.isAdmin
      return Meteor.users.find()
    else
      return Meteor.users.find({_id: @userId})
  Meteor.publish 'Game', ->
    return Game.find {}, {limit: 1}

  Houston.add_collection Meteor.users
  Houston.add_collection Game


  Meteor.startup ->
    ServiceConfiguration.configurations.remove
      service: 'facebook'
    ServiceConfiguration.configurations.insert
      service: "facebook",
      appId: Meteor.settings.fbAppId,
      secret: Meteor.settings.fbSecret

if Meteor.isClient
  Meteor.subscribe 'Players'
  Meteor.subscribe 'Game'

  Template.layout.helpers
    username: ->
      Meteor.user()?.services?.facebook?.first_name || Meteor.user()?.profile.name

    isAdmin: ->
      Meteor.user()?.isAdmin

    loggedIn: ->
      Meteor.user()?

  Template.adminContent.helpers
    gameStarted: ->
      Game.find().count() > 0

    livingUsers: ->
      Meteor.users.find({alive: true}, {sort: {index: 'asc'}}).fetch()

  Template.userContent.helpers
    gameStarted: ->
      Game.find().count() > 0

    target: ->
      Meteor.user()?.targetName

    username: ->
      Meteor.user()?.services?.facebook?.first_name

    dead: ->
      Meteor.user()?.alive == false

    phrase: ->
      Meteor.user()?.secretPhrase

    lastOneStanding: ->
      Meteor.user()? && Meteor.user().profile?.name == Meteor.user().targetName

  Template.gameStartButton.events
    click: (event) ->
      Meteor.call 'startGame'

  Template.loginButton.events
    click: (event) ->
      Meteor.loginWithFacebook (err) ->
        if err?
          console.log err

  Template.assassinateButton.events
    click: (event) ->
      phrase = prompt("If you have assassinated " + Meteor.user().targetName + ", then enter their secret phrase to prove it.")
      Meteor.call 'assassinate', phrase

Meteor.users.allow
  update: (userId, doc) ->
    Meteor.users.findOne(userId).isAdmin

Meteor.users.deny
  update: (userId, doc) ->
    not Meteor.users.findOne(userId).isAdmin

Meteor.methods
  startGame: ->
    phrases = _.shuffle Meteor.settings.phrases
    if Meteor.users.findOne(@userId)?.isAdmin and Game.find().count() == 0
      Game.insert {started: true}
      shuffled = _.shuffle Meteor.users.find({isAdmin: {$ne: true}}).fetch()
      _.each shuffled, (user, index) ->
        target = (index + 1) % shuffled.length
        phrase = phrases[index % phrases.length]
        Meteor.users.update {_id: user._id}, {$set: {index: index, target: target, alive: true, secretPhrase: phrase}}
      _.each Meteor.users.find({isAdmin: {$ne: true}}).fetch(), (user) ->
        targetUser = Meteor.users.findOne {index: user.target}
        Meteor.users.update user._id,
          $set:
            targetName: targetUser.profile.name

  assassinate: (phrase) ->
    user = Meteor.users.findOne @userId
    if not user.alive
      return
    targetUser = Meteor.users.findOne {index: user.target}
    if phrase != targetUser.secretPhrase
      return
    Meteor.users.update @userId,
      $set:
        target: targetUser.target
        targetName: targetUser.targetName
    Meteor.users.update targetUser._id,
      $set:
        alive: false

Meteor.methods
  startGame: ->
    phrases = _.shuffle Meteor.settings.phrases
    if Meteor.users.findOne(@userId)?.isAdmin and Game.find().count() == 0
      Game.insert {started: true}
      shuffled = _.shuffle Meteor.users.find({isAdmin: {$ne: true}}).fetch()
      _.each shuffled, (user, index) ->
        target = (index + 1) % shuffled.length
        phrase = phrases[index % phrases.length]
        Meteor.users.update {_id: user._id}, {$set: {kills: 0, index: index, target: target, alive: true, secretPhrase: phrase}}
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
      $inc: {kills: 1}
    Meteor.users.update targetUser._id,
      $set:
        alive: false

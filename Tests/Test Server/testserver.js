Players = new Meteor.Collection("players");

Meteor.methods({
  anotherMethod: function(data) {
    return Players.insert(data);
  },

  addPlayer: function(data) {
    return Meteor.call("anotherMethod", data);
  },

  addExamplePlayers: function() {
    var names = ["Ada Lovelace", "Grace Hopper", "Marie Curie",
                 "Carl Friedrich Gauss", "Nikola Tesla", "Claude Shannon"];
    _.each(names, function (name) {
      Players.insert({
        name: name,
        score: Math.floor(Random.fraction() * 10) * 5
      });
    });
  },

  reset: function() {
    Players.remove({});
  }
});

if (Meteor.isClient) {
  // counter starts at 0
  Session.setDefault("counter", 0);

  Template.hello.helpers({
    counter: function () {
      return Session.get("counter");
    }
  });

  Template.hello.events({
    'click button': function () {
      // increment the counter when button is clicked
      Session.set("counter", Session.get("counter") + 1);
    }
  });
}

if (Meteor.isServer) {
  Meteor.startup(function () {
    if (Meteor.users.find().count() === 0) {
      Accounts.createUser({ email: "martijn@martijnwalraven.com", password: "correct"})
    }
  });

  Meteor.publish("allPlayers", function() {
    return Players.find();
  });
}

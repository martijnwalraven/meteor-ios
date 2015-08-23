Lists = new Mongo.Collection("lists");
 
if (Meteor.isClient) {
  // This code only runs on the client
   Template.body.helpers({
    lists: function () {
      // Show newest tasks at the top
      return Lists.find({}, {sort: {name: 1}});
    }
  });

  Template.body.events({
    "submit .new-list": function (event) {
      // Prevent default browser form submit
      event.preventDefault();
 
      // Get value from form element
      var text = event.target.text.value;
 
      // Insert a task into the collection
      Lists.insert({
        name: text,
      });
 
      // Clear form
      event.target.text.value = "";
    }
  });
}
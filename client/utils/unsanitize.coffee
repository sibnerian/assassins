# The ampersand is sent as &amp; which doesn't render in the document title
# This hack can be removed if/when Meteor adds reactive templating for the <title> attribute
@unsanitize = (str) ->
  str.replace '&amp;', '&'
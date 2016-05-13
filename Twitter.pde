// Initial connection
void connectTwitter() {
  twitter.setOAuthConsumer(OAuthConsumerKey, OAuthConsumerSecret);
  AccessToken accessToken = loadAccessToken();
  twitter.setOAuthAccessToken(accessToken);
}

// Loading up the access token
private static AccessToken loadAccessToken() {
  return new AccessToken(AccessToken, AccessTokenSecret);
}

// Sending a tweet
void sendTweet() {
  //println("will print", entirePoem);
  try {
    Status status = twitter.updateStatus(entirePoem);
    println("tweeted [" + status.getText() + "].");
  } catch (TwitterException e) {
    println("Send tweet: " + e + " Status code: " + e.getStatusCode());
  }
}
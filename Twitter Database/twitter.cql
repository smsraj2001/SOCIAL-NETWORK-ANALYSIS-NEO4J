MATCH (n:User) RETURN n LIMIT 25
MATCH (n:Tweet) RETURN n LIMIT 25

// 1. Which platform are users tweeting from most often?
MATCH (t:Tweet)-[:USING]->(s:Source)
RETURN s.name as Source, count(t) as Count
ORDER BY Count DESC
LIMIT 5

// 2. Which hashtags co-occur with #python most frequently? 
MATCH (:Hashtag {name:'python'})<-[:TAGS]-(:Tweet)-[:TAGS]->(h:Hashtag)
RETURN h.name AS Hashtag, COUNT(*) AS Count
ORDER BY Count DESC
LIMIT 5

// 3. Which tweet has been retweeted the most, and who posted it? 
MATCH (:Tweet)-[:RETWEETS]->(t:Tweet)
WITH t, COUNT(*) AS Retweets
ORDER BY Retweets DESC
LIMIT 10
MATCH (u:User)-[:POSTS]->(t)
RETURN u.screen_name AS User, t.text AS Tweet, Retweets

// 4. Entire graph
MATCH (t:Tweet)
WITH t ORDER BY t.id DESC LIMIT 2000
MATCH (user:User)-[:POSTS]->(t)-[:TAGS]->(tag:Hashtag)
MATCH (t)-[:MENTIONS]->(user2:User)  
UNWIND [tag,user2] as other WITH distinct user,other
RETURN { from: {id:id(user),label: head(labels(user)), data: user},
    rel: 'CONNECTS',
    to: {id: id(other), label: head(labels(other)), data: other}} as tuple
LIMIT 1000

// 5. Links from interesting retweets
MATCH (:User {screen_name: 'neo4j'})-[:POSTS]->
  (t:Tweet)-[:RETWEETS]->(rt)-[:CONTAINS]->(link:Link)
RETURN t.id_str AS tweet, link.url AS url, rt.favorites AS favorites
ORDER BY favorites DESC LIMIT 10

// 6. Most tagged by an user
MATCH
  (h:Hashtag)<-[:TAGS]-(t:Tweet)<-[:POSTS]-(u:User {screen_name:'neo4j'})
WITH 
  h, COUNT(h) AS Hashtags
ORDER BY 
  Hashtags DESC
LIMIT 10
RETURN 
  h.name, Hashtags

// 7. Users tweeting an user, but not following back
MATCH (ou:User)-[:POSTS]->(t:Tweet)-[mt:MENTIONS]->(me:User {screen_name: 'neo4j'})
WITH DISTINCT ou, me
WHERE (ou)-[:FOLLOWS]->(me)
AND NOT (me)-[:FOLLOWS]->(ou)
RETURN ou.screen_name
LIMIT 20

// 8. Users tweeting with common tags as an user 
MATCH (me:User {screen_name:'neo4j'})-[:POSTS]->(tweet:Tweet)-[:TAGS]->(ht)
OPTIONAL MATCH (tweet)<-[:RETWEETS]-(retweet)
WITH me,ht, collect(distinct retweet) as retweets
MATCH (ht)<-[:TAGS]-(tweet2:Tweet)<-[:POSTS]-(sugg:User)
WHERE sugg <> me and NOT(tweet2 IN retweets)
WITH sugg, count(distinct(ht)) as common
RETURN sugg.screen_name as friend, common
ORDER BY common DESC
LIMIT 20

// 9. Top mentions of an User 
MATCH
  (u:User)-[:POSTS]->(t:Tweet)-[:MENTIONS]->(m:User {screen_name:'neo4j'})
RETURN
  u.screen_name AS screen_name, COUNT(u.screen_name) AS count 
ORDER BY 
  count 
DESC LIMIT 10

// 10. Which other topics could we recommend for a specific user? Finding the most frequently co-occurring topics to the ones they used and that they haven’t used themselves.
MATCH (u:User {screen_name:"neo4j"})-[:POSTS]->(tweet)
    -[:TAGS]->(tag1:Hashtag)<-[:TAGS]-(tweet2)-[:TAGS]->(tag2:Hashtag)
WHERE NOT (u)-[:POSTS]->()<-[:TAGS]-(tag2) AND tag1.name <> 'neo4j' AND tag2.name <> 'neo4j'
RETURN tag2.name as Topics, count(*) as Count
ORDER BY count(*) DESC LIMIT 5

// 11. Creating a graph structure for the centratlity measure

CALL gds.graph.project(
  'graph',
  'User',
  'FOLLOWS'
)


// 12. CENTRALITY MEASURE
CALL gds.pageRank.stream('graph')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).screen_name as screenName, 
score, gds.util.asNode(nodeId).followers as followersCount
ORDER BY score DESC LIMIT 10;

// 13. COMMUNITY DETECTION
CALL gds.louvain.stream('graph')
YIELD nodeId, communityId
WITH communityId AS communityId, size(collect(nodeId)) as size
RETURN communityId, size
ORDER BY size DESC;
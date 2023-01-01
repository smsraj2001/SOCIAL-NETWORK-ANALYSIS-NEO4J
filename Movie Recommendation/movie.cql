// C:\Users\user_name\.Neo4jDesktop\relate-data\dbmss\name_of_folder_after_database_created\import


// 0. To delete all nodes and relationships
MATCH (n)
DETACH DELETE n

// CONTENT BASED FILTERING

// 1. To create users
load csv from 'file:///shows.csv' as row with row, toInteger(row[0]) as id, row[1] as labels, row[2] as follows, row[3] as name, row[4] as surname, 
toInteger(row[5]) as start, toInteger(row[6]) as end, row[7] as type, toFloat(row[8]) as rating 
where labels = ":User"
create(:User{id:id, name:name, surname:surname})

match(n) return n

// 2. To create categories
load csv from 'file:///shows.csv' as row with row, toInteger(row[0]) as id, row[1] as labels, row[2] as follows, row[3] as name, row[4] as surname, 
toInteger(row[5]) as start, toInteger(row[6]) as end, row[7] as type, toFloat(row[8]) as rating 
where labels = ":Category"
create(:Category{id:id, name:name})

match(n) return n

// 3. To create shows
load csv from 'file:///shows.csv' as row with row, toInteger(row[0]) as id, row[1] as labels, row[2] as follows, row[3] as name, row[4] as surname, 
toInteger(row[5]) as start, toInteger(row[6]) as end, row[7] as type, toFloat(row[8]) as rating 
where labels = ":Show"
create(:Show{id:id, name:name, follows:follows})

match(n) return n


// 4. To create relationship: watch

load csv from 'file:///shows.csv' as row with row, toInteger(row[0]) as id, row[1] as labels, row[2] as follows, row[3] as name, row[4] as surname, 
toInteger(row[5]) as start, toInteger(row[6]) as end, row[7] as type, toFloat(row[8]) as rating 
where type = "WATCH"
match(u:User) where u.id = start
match(s:Show) where s.id = end
create (u)-[:WATCH{rating:rating}]->(s)


// 5. To create relationship: has_category

load csv from 'file:///shows.csv' as row with row, toInteger(row[0]) as id, row[1] as labels, row[2] as follows, row[3] as name, row[4] as surname, 
toInteger(row[5]) as start, toInteger(row[6]) as end, row[7] as type, toFloat(row[8]) as rating 
where type = "HAS_CATEGORY"
match(s:Show) where s.id = start
match(c:Category) where c.id = end
create (s)-[:HAS_CATEGORY]->(c)

// 6. Recommending  TV shows for a user:Tom Hardy based on user history :-(sc is Shows already seen, s2 : User not watched category, z : )

match(u:User{name:"Tom",surname:"Hardy"})-[:WATCH]->(s:Show)-[:HAS_CATEGORY]->(c:Category)<-
[:HAS_CATEGORY]-(z:Show)
where not exists((u)-[:WATCH]->(z))
with s, z, count(c) as intersection 
match(s)-[:HAS_CATEGORY]->(sc:Category)
with s,z,intersection,COLLECT(sc.name) as s1
match(z)-[:HAS_CATEGORY]->(zc:Category)
with s,z,s1,intersection, COLLECT(zc.name) as s2
with s,z,intersection, s1 + [x in s2 where not x in s1] as union,s1,s2
return s.name as UserShow, z.name as Recommendate, s1 as UserShowCategory, s2 as RecommendateShowCategory,
((1.0 * intersection)/SIZE(union)) as jaccard
order by jaccard desc

// 7. Same as above using inbuilt library

match(u:User{name:"Tom",surname:"Hardy"})-[:WATCH]->(s:Show)-[:HAS_CATEGORY]->(c:Category)<-
[:HAS_CATEGORY]-(z:Show)
where not exists((u)-[:WATCH]->(z))
with s,z
match(s)-[:HAS_CATEGORY]->(sc:Category)
with s,z,COLLECT(DISTINCT(id(sc)) as s1
match(z)-[:HAS_CATEGORY]->(zc:Category)
with s,z,s1,COLLECT(DISTINCT(id(zc)) as s2
with s,z,s1,s2
return s.name as UserShow, z.name as Recommendate, s1 as
UserShowCategory, s2 as RecommendateShowCategory, 
gds.aplha.similarity.jaccard(s1,s2) as jaccard
order by jaccard desc


// COLLABORATIVE BASED FILTERING

match(s.show)
with collect(s.name) as shows
match(u:User{name:"Tom", surname:"Hardy"})-[:WATCH]->(z:Show)
with shows, collect(z.name) as myshow, u
with shows, myshow, gds.alpha.m1.oneHotEncoding(shows,myshow) as showu1,u
match(o:User)-[:WATCH]->(x:Show)
where u<>o
with shows, collect(x.name) as otherusershow, myshow, showu1,o,u
with showu1,gds.aplha.ml.oneHotEncoding(shows,otherusershow) as showu2,o,u
with o,gds.aplha.similarity.cosine(showu1,showu2) as simindex, u
order by simindex desc limit 1
with u,o
match(o:User)-[:WATCH]->(s:Show)
where not exists((u)-[:WATCH]->(s))
return s
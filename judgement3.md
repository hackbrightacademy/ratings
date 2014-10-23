Judgemental Eye: Being a Walkthrough on Building a Movie Rating App
===================================================================
By this time, our judgemental app should be approaching feature completion for a basic version. Check out the [reference version](http://intense-bastion-5418.herokuapp.com/) and the [source](https://github.com/chriszf/ratings/tree/deployed) to determine the minimum app you need to build.

You may be wondering at this point, where the judgement comes into play with the judgemental eye. Well, wonder no more. We're going to build it.

Chapter 0: In Which We Learn To Judge
-------------------------------------
The core to the concept of the 'judgemental eye' is something called the _Pearson correlation_. The Pearson correlation is a way to judge how similar two things are to each other, based on some arbitrary shared number. An abstract definition is difficult to grasp, so we'll look at a simple example using film ratings.

    Movies:     Movie A     Movie B
    User 1:        5           3
    User 2:        5           3

Let's say we wanted to produce a number that indicated how similar User 1 was to User 2. Arbitrarily, we'll choose a scale from -1 to 1, with -1 being complete opposites, and 1 being twins in terms of similarity. Looking at our table above, we can intuit that because they have identical ratings for the two movies in question, they're a 1.0 in terms of similarity on our scale. Let's expand the table.

    Movies:     Movie A     Movie B     Movie C
    User 1:        5           3           4
    User 2:        5           3           5
    User 3:        -           3           5

In our new table, we have new information, and can make new statements about our users and movies. User 1 and User 2 are still very similar, but for Movie C, they have differing ratings. The difference in that rating isn't much, and when taken as a whole with the other two movies, User 1 really isn't all that different from User 2. They're not a perfect 1.0 anymore, but close, perhaps above a 0.9. On the other hand, for the two movies they have in common, User 2 and User 3 have identical ratings. User 3 doesn't have an entry for Movie A, perhaps because they haven't seen it, but as far as we know, User 2 and User 3 have exactly the same tastes, and are a 1.0 in terms of similarity.

Let's transpose the table, putting movies on the Y-axis, and users on the X-axis:

    Users:      User 1      User 2      User 3
    Movie A:        5           5           -
    Movie B:        3           3           3
    Movie C:        4           5           5

Looking at it this way, we can extract some slightly different data. Comparing the ratings across rows, we can see that for the users who've seen it, Movie A is very similar to Movie C. The users the two movies have in common have rated the movie similarly. On the other hand, Movie B is not especially similar to either Movie A or Movie C; there doesn't seem to be much of a correlation at all. It's hard to say, based on the rows, whether liking Movie C is any indication of liking Movie B.

Let's look at one more table:

    Movies:     Movie A     Movie B     Movie C
    User 1:        5           3           4
    User 2:        5           3           5
    User 3:        -           3           5
    User 4:        1           3           2
    User 5:        2           2           2

User 4 seems to have completely opposite ratings from User 1, consistently so. This is an example of a users who have negative correlations, a full -1.0. They're predictably opposite each other for all the movies that they've both seen. User 5, on the other hand, rates completely independently from User 1. User 1 rating something high doesn't give any indication of whether User 5 will rate low or high.

We can take this idea and formalize it. For any row in these tables, similarity can be determined by how _close_ their ratings are to each other for the any columns they have in common. Specifically, we can determine closeness of two ratings by subtracting one from the other. If we take those deltas and square them, then do some clever arithmetic to normalize the number so that it falls between -1 and 1, we get the Pearson correlation:

    # Calculate the pearson score
    num_critics = len(common_critics)
    num = product_sum - ((film1_sum * film2_sum)/num_critics)
    den = sqrt((film1_sum_square - pow(film1_sum, 2) / num_critics) * \
        (film2_sum_square - pow(film2_sum, 2)/num_critics))
    pearson = num/den

**Now this is critical:** derive the Pearson correlation from first principles on a whiteboard.

Just kidding. Here's an example of a piece of code we don't need to fully understand. From a high level, it finds all the common columns between two rows in our data table, takes the difference between the two, and blends it into a fraction between -1 and 1 that represents the similarity between the rows. That's sufficient to understand how to use it. In fact, we can go even higher and still be able to use this function: if we feed two lists of ratings into a Pearson function, we get a number that represents similarity. You'll find an implementation of the Pearson correlation in [correlation.py](https://gist.github.com/3994667). You'll want to import this file from your model.py file.
    
Obviously, it's difficult to draw broad, sweeping generalizations based off of 15 datapoints. Fortunately, we have close to 100,000 datapoints, courtesy of the ML-100k dataset. With bigger datasets, we can make more accurate and definitive claims about how users and movies are similar to each other.

### So What?
Imagine that you know User A and User B have a correlation of 1.0 over the span of 20 movies: they vote identically for the things that are common between them. User A now watches some movie X and rates it a 5. What would you expect User B to rate the same movie?

It's only sensible that expect that User B will also rate it a 5, given their history. Using this knowledge, we can predict how a user will rate a movie simply by finding another user with a high correlation coefficient who has seen the movie in question. The first user's rating will likely be somewhere in the region of the second user. The converse is true: if we find a user with a negative correlation, we can just take _their_ rating and invert it.

Using this, we can now build the **Judgemental Eye**.

Chapter 1: In Which We Teach a Computer to Love... and Hate.
------------------------------------------------------------
The Judgemental Eye is a malevolent being whose sole purpose in life is to pass judgement on people's movies tastes. Here is the behavior of the Eye:

1. When a user views a movie they haven't rated, the Eye predicts how that user will rate that movie.
2. Once a user has either rated the movie or received a prediction, the Eye will find its own rating for that movie, predicting the number if it has to.
3. The Eye will take the difference of the two ratings, and criticize the user for their tastes.

All of this hinges on a way to guess how a person (the user, or **The Eye**) would rate a movie. If the person has already rated the movie, we can just use that number. If they haven't, we have to guess. Here's the process for guessing:

1. Given a user U who has not rated movie X, find all _other_ users who have rated that movie.
2. For each other user O, find the movies they have rated in common with user U.
3. Pair up the common movies, then feed each pair list into the pearson function to find similarity S.
4. Rank the users by their similarities, and find the user with the highest similarity, O'.
5. Multiply the similarity coefficient of user O' with their rating for movie X. This is your predicted rating.

In a simple case, if user U needs a prediction for Toy Story, we first find everyone else who has seen Toy Story, and collect all their movie ratings. Using their ratings, we can run a pearson correlation and find user V who rates movies very similarly to user U, with a coefficient of 0.9. If user V rated Toy Story at 5 stars, it's not unreasonable to guess that user U will rate it at 5 * 0.9 = 4.5 stars.

It sounds complicated, but we'll break down each step in code. Start python, loading your model file in interactive mode (python -i model.py). First, we'll grab a user who hasn't seen Toy Story, as well as the movie record itself. For the purpose of this example, we know the user with id 1 hasn't rated it.

### Step 1
    >>> m = session.query(Movie).filter_by(title="Toy Story").one()
    >>> u = session.query(User).get(1)

Now, we need to get a list of his ratings

    >>> ratings = u.ratings

Next, we need to get a list of other users who _have_ rated the movie:

    >>> other_ratings = session.query(Rating).filter_by(movie_id=m.id).all()
    >>> other_users = []
    >>> for r in other_ratings:
    ...     other_users.append(r.user)


### Steps 2, 3
We'll need to go through each user and find the movies they have in common in with our first user to be able to use our pearson function:

    >>> """
    User A:
        Movie 1: 5
        Movie 2: 3
        Movie 3: 4
        Movie 4: 2

    User B:
        Movie 1: 5
        Movie 2: 3
        Movie 4: 3
    
    We collect the common movies, 1,2 and 4, and group them by pairs. The first element in the pair is user A's rating. The second is user B's. It doesn't matter what order the movies are paired in as long as they match up.
    """
    >>> import correlation
    >>> rating_pairs = [(5, 5), (3, 3), (2, 3)]
    >>> print correlation.pearson(rating_pairs)
    0.944911182523

At this point, I encourage you to figure out how to generate that pair list on your own and skip straight to step 4. If you need a little assistance, read on.

From before, we have our user **u**, and our list of other users, **other_users**. First, let's peel off a single user from the list to test against.

    >>> o = other_users[0]

Now, we want to go through _o.ratings_ and find out if any of those ratings pair up with our first user's ratings. We could do something naive like this:

    >>> paired_ratings = []
    >>> for r1 in u.ratings:
    ...     for r2 in o.ratings:
    ...         if r1.movie_id == r2.movie_id:
    ...             paired_ratings.append( (r1.rating, r2.rating) )

The problem with this is that it is what we call O(n^2) performance. Assume that user u has N ratings, and user o has N ratings as well. The two loops in this example tell the computer to loop through u.ratings, and for each rating in that list, loop through o.ratings to find a match, based on movie\_id of each rating. This means it has to loop N * N times to go through all the rating pairs. If they both have a lot of ratings, this query could potentially take a long time. Let's try something different with dictionaries. Experiment first on your own.

<div class="spoilers">

    >>> u_ratings = {}
    >>> for r in u.ratings:
    ...     u_ratings[ r.movie_id ] = r
    >>> paired_ratings = []
    >>> for o_rating in o.ratings:
    ...     u_rating = u_ratings.get(o_rating.movie_id)
    ...     if u_rating:
    ...         pair = (u_rating.rating, o_rating.rating)
    ...         paired_ratings.append(pair)
</div>

This example requires a bit more code, but not too much more. The first thing it does is create a dictionary, and loop through u.ratings, putting every rating in the dictionary, using the movie\_id for that rating as the key. Second, it loops through o.ratings, then checks to see if there's a record in the dictionary that matches the movie\_id. That would mean that the user u _also_ rated the movie in question. If they did, then just put that pair of ratings in our pair list. This is useful, and we're going to do this once for each user, so we should put it in a function. We should also feed the pair list to the pearson() function at the end, if there's at least one pair in it. We could put this as a free-standing function in the model file:

<div class="spoilers">

    import correlation 

    ...

    def similarity(user1, user2):
        u_ratings = {}
        paired_ratings = []
        for r in user1.ratings:
            u_ratings[r.movie_id] = r

        for r in user2.ratings:
            u_r = u_ratings.get(r.movie_id)
            if u_r:
                paired_ratings.append( (u_r.rating, r.rating) )

        if paired_ratings:
            return correlation.pearson(paired_ratings)
        else:
            return 0.0
</div>

But, we can do one better. Since this function returns the similarity of users, we can put this on the User class.

<div class="spoilers">

    class User(Base):
        ...

        def similarity(self, other):
            u_ratings = {}
            paired_ratings = []
            for r in self.ratings:
                u_ratings[r.movie_id] = r

            for r in other.ratings:
                u_r = u_ratings.get(r.movie_id)
                if u_r:
                    paired_ratings.append( (u_r.rating, r.rating) )

            if paired_ratings:
                return correlation.pearson(paired_ratings)
            else:
                return 0.0
</div>

Now, we can do this in an interactive shell:

    >>> u1 = session.query(User).get(1)
    >>> u2 = session.query(User).get(2)
    >>> print u1.similarity(u2)
    0.16084123285437085

### Step 4 and 5
Given a list of users, we can find their similarity coefficients:

    >>> m = session.query(Movie).filter_by(title="Toy Story").one()
    >>> u = session.query(User).get(1)
    >>> ratings = u.ratings
    >>> other_ratings = session.query(Rating).filter_by(movie_id=m.id).all()
    >>> other_users = []
    >>> for r in other_ratings:
    ...     other_users.append(r.user)

    >>> for other_u in other_users:
            print u.similarity(other_u)

Now, we want to rank them. Again, there are a lot of ways to do this, and you should try on your own, but read on for hints.

The easiest way to rank users is by using the built-in tuple sort mechanism:

<div class="spoilers">

    >>> users = []
    >>> for other_u in other_users:
    ...     similarity = u.similarity(other_u)
    ...     pair = (similarity, other_u)
    ...     users.append(pair)
    >>> sorted_users = sorted(users, reverse=True)
    >>> top_user = sorted_users[0]
</div>

Given the top user, we can then use the similarity coefficient to make a prediction.

<div class="spoilers">

    >>> sim, best_match = top_user
    >>> best_rating = session.query(Rating).filter_by(movie_id = m.id, user_id = best_match.id).one()
    >>> predicted_rating = sim * best_rating.rating
</div>

Let's take this all and put this in a function, again in model.py.

<div class="spoilers">

    def predict_rating(user, movie):
        ratings = user.ratings
        other_ratings = movie.ratings
        other_users = [ r.user for r in other_ratings ]
        similarities = [ (user.similarity(other_user), other_user) \
            for other_user in other_users ]
        similarities.sort(reverse = True)
        top_user = similarities[0]
        matched_rating = None
        for rating in other_ratings:
            if rating.user_id == top_user[1].id
                matched_rating = rating
                break
        return matched_rating.rating * top_user[0]

</div>


Take a look at this function. It's slightly different from the console commands we typed in. We use [list comprehensions](http://docs.python.org/2/tutorial/datastructures.html#list-comprehensions), which are a way to combine certain types of for-loops and lists. On top of that, instead of querying the database for the matching rating record, we just search through the list we already have. Make sure you're comfortable lining up the 'experimental version' with the final version before moving on.

Once again, since this is a method pertaining to users and movies, it makes sense to be an instance method. The question is, does it go on the user instance or the movie instance? In this case, it's English to the rescue. A user will predict their rating of a given movie, so we'll put it there.

<div class="spoilers">
    
    class User(Base):
        ...
        
        def predict_rating(self, movie):
            ratings = self.ratings
            other_ratings = movie.ratings
            other_users = [ r.user for r in other_ratings ]
            similarities = [ (self.similarity(other_user), other_user) \
                for other_user in other_users ]
            similarities.sort(reverse = True)
            top_user = similarities[0]
            matched_rating = None
            for rating in other_ratings:
                if rating.user_id == top_user[1].id:
                    matched_rating = rating
                    break
            return matched_rating.rating * top_user[0]
</div>

And again, we can do something like this:

    >>> u = session.query(User).get(1)
    >>> m = session.query(Movie).get(300)
    >>> print u.predict(m)
    1.0000000000000013

Note, this may take a long time to run, as a lot of queries are being made. But now, we have a simply interface to predict how a user will rate a movie. But... it's not very good. Intuitively, the prediction number here is too close to 1 to seem correct. Let's stop and see why.

If we inject some print statements into our function to see what the similarities are like, we can see that there are quite a few users who have a similarity of 1.0. This is a weakness of this method: the fewer ratings you have, the less accurate it is. The users who are rated 1.0 in similarity are a statistical quirk. It's quirky enough that we can't use _just one_ user, we'll have to blend our results together.

To blend the users, we'll need to keep track of how similar a user is, as well as their actual rating. We'll change our tuple around, instead of having it be composed of (similarity coeffecient, user instance), we'll make it (similarity coefficient, rating).

<div class="spoilers">

        def predict_rating(self, movie):
            ratings = self.ratings
            other_ratings = movie.ratings
            similarities = [ (self.similarity(r.user), r) \
                for r in other_ratings ]
            similarities.sort(reverse = True)
            top_user = similarities[0]
            return top_user[1].rating * top_user[0]
</div>

This has the added bonus of simplifying our function by quite a bit, since we don't have to do a second pass over the ratings list to find the appropriate rating: they're already matched with the correct similarity.

Still, this is functionally equivalent to our previous iteration, which gives us bad results. We still need to blend them. The simplest mechanism for blending is called the weighted mean. It's a lot like an average, but instead of summing all the ratings and dividing by the number of ratings, we do something that gives more weight to users who are more similar:

    weighted mean:
    mean = sum(ratings * coefficients ) / sum(coefficients)

Thus, our python changes:

<div class="spoilers">

        def predict_rating(self, movie):
            ratings = self.ratings
            other_ratings = movie.ratings
            similarities = [ (self.similarity(r.user), r) \
                for r in other_ratings ]
            similarities.sort(reverse = True)
            numerator = sum([ r.rating * similarity for similarity, r in similarities ])
            denominator = sum([ similarity[0] for similarity in similarities ])
            return numerator/denominator
</div>

This is better, but not perfect. The existence of negative similarities has the potential to push our prediction _beyond_ the 1 to 5 rating system. We have sufficient information in the positive similarities that we can throw them out. (Although mathematically, we'd do better to rescale our rating system between -1 to 1, use the negative coefficients, then rescale it back.) Filter out the negative similarities now, being sure to check that you still have some ratings left to work with after throwing out negative values:

<div class="spoilers">

        def predict_rating(self, movie):
            ratings = self.ratings
            other_ratings = movie.ratings
            similarities = [ (self.similarity(r.user), r) \
                for r in other_ratings ]
            similarities.sort(reverse = True)
            similarities = [ sim for sim in similarities if sim[0] > 0 ]
            if not similarities:
                return None
            numerator = sum([ r.rating * similarity for similarity, r in similarities ])
            denominator = sum([ similarity[0] for similarity in similarities ])
            return numerator/denominator
</div>

This looks pretty good, let's see how it predicts:

    >>> u = session.query(User).get(1)
    >>> m = session.query(Movie).get(300)
    >>> print u.predict_rating(m)
    3.610924095880413

Not bad.

### BONUS ROUND (Optional)
You'll notice that this prediction is fairly similar to the overall average for the movie. This is because we're essentially taking that average, and giving users who are more similar to you more of a precedence. This is _reasonable_, but not necessarily the best way to do this. We can get something slightly more interesting (perhaps) by taking all the movies you've rated, finding out which movie it's most similar to, and then multiplying your rating of that movie by its similarity to get a prediction. This represents your preferences more than it represents your similarity to other people. Try doing this by adding the similarity method to the Movie class (a fine time to do inheritance), then changing the User prediction method to use that instead.

Chapter 2: In Which We Make Our App Predictive
----------------------------------------------
To add prediction to our app, we simply have to, when a user views a movie, call the prediction function and display the results. In the reference implementation, the view we want to modify is **view_movie**.

<div class="spoilers">

    @app.route("/movie/<int:id>", methods=["GET"])
    def view_movie(id):
        movie = db_session.query(Movie).get(id)
        ratings = movie.ratings
        rating_nums = []
        user_rating = None
        for r in ratings:
            if r.user_id == session['user_id']:
                user_rating = r
            rating_nums.append(r.rating)
        avg_rating = float(sum(rating_nums))/len(rating_nums)

        # Prediction code: only predict if the user hasn't rated it.
        user = db_session.query(User).get(session['user_id'])
        prediction = None
        if not user_rating:
            prediction = user.predict_rating(movie)
        # End prediction
        
        return render_template("movie.html", movie=movie, 
                average=avg_rating, user_rating=user_rating,
                prediction=prediction)
</div>

Then, we can add an if statement in our template, movie.html, that shows the prediction if it exists:

<div class="spoilers">

    {% if prediction %}
    <h3>We predict you will rate this movie {{prediction}}.</h3>
    {% endif %}
</div>

And we're done!

...

Chapter 3: In Which We Build a Being of Pure Malice
---------------------------------------------------
Everything is now in place to build **The Eye**. Hopefully, you can guess how, but we'll do this step by step.

In terms of our system, **The Eye** is just a user with bad taste in movies. Every time you view a movie, **The Eye** will either get its rating or predict its own rating for the same movie, then it will berate you endlessly for how dissimilar your tastes run, based on the difference between your ratings.

The first thing to do is create a user to be the judgemental eye. It can be an existing user, a real user, or an imaginary user. As an example, we'll make a new user. Running model.py in interactive mode:

    >>> eye = User(email="theeye@ofjudgement.com", password="securepass")
    >>> session.add(eye)
    >>> session.commit()
    >>> session.refresh(eye)

Next, we'll choose some movies

    >>> m1 = session.query(Movie).get(1) # toy story
    >>> m2 = session.query(Movie).get(1274) # robocop 3
    >>> m3 = session.query(Movie).get(373) # Judge dredd
    >>> m4 = session.query(Movie).get(314) # 3 ninjas
    >>> m5 = session.query(Movie).get(95) # aladdin
    >>> m6 = session.query(Movie).get(71) # the lion king

And then we'll rate those movies

    >>> r = Rating(user_id = eye.id, movie_id=m1.id, rating=1)
    >>> session.add(r)
    >>> r = Rating(user_id = eye.id, movie_id=m2.id, rating=5)
    >>> session.add(r)
    >>> r = Rating(user_id = eye.id, movie_id=m3.id, rating=5)
    >>> session.add(r)
    >>> r = Rating(user_id = eye.id, movie_id=m4.id, rating=5)
    >>> session.add(r)
    >>> r = Rating(user_id = eye.id, movie_id=m5.id, rating=1)
    >>> session.add(r)
    >>> r = Rating(user_id = eye.id, movie_id=m6.id, rating=1)
    >>> session.add(r)
    >>> session.commit()

Now, **The Eye** officially has bad taste. The Eye can be made more interesting by giving it more ratings.

Next, we want to add **The Eye's** opinion to our movie view. We modify our prediction code.

    # Prediction code: only predict if the user hasn't rated it.
    user = db_session.query(User).get(session['user_id'])
    prediction = None
    if not user_rating:
        prediction = user.predict_rating(movie)
        effective_rating = prediction
    else:
        effective_rating = user_rating.rating

    the_eye = db_session.query(User).filter_by(email="theeye@ofjudgement.com").one()
    eye_rating = db_session.query(Rating).filter_by(user_id=the_eye.id, movie_id=movie.id).first()

    if not eye_rating:
        eye_rating = the_eye.predict_rating(movie)
    else:
        eye_rating = eye_rating.rating

    difference = abs(eye_rating - effective_rating)
    
Finally, we use the difference to get a message. We know that the maximum difference between a user's opinion and the eye's opinion is going to be 4, at the most (If you rate something a 5 and it rates something a 1, or vice versa). If we take the difference, we can use that to choose a message to display.

    messages = [ "I suppose you don't have such bad taste after all.",
                 "I regret every decision that I've ever made that has brought me to listen to your opinion.",
                 "Words fail me, as your taste in movies has clearly failed you.",
                 "That movie is great. For a clown to watch. Idiot.",

    beratement = messages[int(difference)]

We can then pass this beratement to the template and display it somewhere prominent. See if you can figure out how to make the eye choose from a wider selection of messages (hint, multiply the difference by something). Then, make your eye more _evil_.

Chapter 4: The End
------------------
Congratulations. You've completed an exercise in databases, machine learning, and web development. This is a lot to take in, don't be afraid to review everything you've done here, and try to do it again. It should be faster the second time around. Practice makes perfect, etc.

Next steps are gussying up the app to be pretty, making it terrible to behold. You're officially instructed to go wild.

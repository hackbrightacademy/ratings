Judgemental Eye: Being a Walkthrough on Building a Movie Rating App
===================================================================
Already, SQLAlchemy has saved us a metric tonne of time setting up the connection between our python code and our database, but we haven't yet seen the most important part. In this section, we're going to look at how SQLAlchemy (abbreviated as SA, going forward) makes dealing with _relations_ in our relational database much easier.

Once all our data is in place, we can begin to analyze it. We'll use a technique called pearson correlation to measure how similar movies and users are to each other, and use that to predict a user's tastes.

Chapter 0: In Which We Practice Querying
----------------------------------------
One of the things which we haven't explored is SA's querying capabilities. The basic query is the 'get', which works by querying on primary keys. When you type something like this in python:

    user = session.query(model.User).get(5)

It translates to the following SQL query:

    select * from users where id = 5;

We can query on specific fields:

    # Returns the _first_ movie named Aladdin
    al = session.query(model.Movie).filter_by(title = "Aladdin").first()

We can add multiple restrictions:

    # Returns one movie named Aladdin, released in 1992
    al = session.query(model.Movie).\
                filter_by(title = "Aladdin", 
                          release_year = 1992).one() 

(Before you complain, I'm fully aware we haven't made release\_year a property of our Movie object.)

We can get multiple results back:

    # Returns all movies named Aladdin
    al_list = session.query(model.Movie).filter_by(title="Aladdin").all()

The rules for doing these queries may seem complicated, but in reality, they're quite simple and consistent. We'll break up a query to see how it works:

    query = session.query(model.Movie)
    query = query.filter_by(title = Aladdin)
    results = query.all()

In the first line, we create a query that works against the _movies_ table. In essence, it sets up the 'select * from movies' part of a query.

The second line adds a filter, which is directly analogous to the 'where' clause. Here, it translates to 'where title="Aladdin"' part of the query line.
    
Finally, the last line tells the query to execute and return the instance objects that match the query. The '.all()' part tells SA to return a list of all matching instances. There are two other methods that could be called instead, .first() and .one()

    .all() - returns a list of all matching instances
    .first() - returns the first matching instance
    .one() - returns the _only_ matching instance if exactly one row
             matches, throws an error if there are zero or more than 
             one match.

Practice querying. In particular, see if you can figure out how to query a date range and select all movies between 1970 and 1973. As an extra exercise, use SA to write a query that matches all movies that begin with the letter 'q'. Use the [SA tutorial](http://docs.sqlalchemy.org/en/rel_0_7/orm/tutorial.html#querying) on querying as a start.

Chapter 1: In Which We Wed Our Data to Itself
---------------------------------------------
In the last tutorial, we came up with the following relations in our schema:

    A user has many ratings
    A rating belongs to a user
    A movie has many ratings
    A rating belongs to a movie
    A user has many movies through ratings
    A movie has many users through ratings

Given our newfound querying abilities, can find the titles for all the movies user 35 has rated. Try this now in your interactive shell after running 'python -i model.py'.

    user = session.query(model.User).get(35)
    ratings = session.query(model.Rating).filter_by(user_id=user.id).all()
    movies = []
    for r in ratings:
        movie = session.query(model.Movie).get(r.movie_id)
        movies.append(movie)

    for m in movies:
        print movie.title

Not bad, but there's still a bit of code. Given one record in the user table, we have to manually query for the appropriate rows in the other two tables. On top of that, it requires 1 query to get the user, 1 query to get all of that user's ratings, and then N queries to get all of the movies. If you'll recall, we can use SQL joins to get all that data at once, but it's not obvious how joins fit into SA's mechanisms.

SA has a mechanism called a 'relationship' that uses SQL joins, but hides the nitty-gritty from you. Let's update our model.py file. Add the following imports to the top of the file:

    from sqlalchemy import ForeignKey
    from sqlalchemy.orm import relationship, backref

We'll implement the relationship between Users and Ratings first: a User has many Ratings. Find your Rating model. If you imitated the examples from the previous exercise, it probably looks like this:

    class Rating(Base):
        __tablename__ = "ratings"
        id = Column(Integer, primary_key = True)
        user_id = Column(Integer)
        movie_id = Column(Integer)
        rating = Column(Integer)

Notice we don't have an \_\_init\_\_ method in this example. Instead, we're just using the [default SA init](http://docs.sqlalchemy.org/en/rel_0_7/orm/tutorial.html#declare-a-mapping) that lets us use keyword arguments to initalize an object.

Let's update the class:

    class Rating(Base):
        __tablename__ = "ratings"
        id = Column(Integer, primary_key = True)
        user_id = Column(Integer, ForeignKey('users.id'))
        movie_id = Column(Integer)
        rating = Column(Integer)

        user = relationship("User",
                backref=backref("ratings", order_by=id))

Let's break this down. The first change is the new definition for the user\_id.

        user_id = Column(Integer, ForeignKey('users.id'))

The column is still an integer, but we're also declaring it to be a ForeignKey, which is just a fancy way of saying it references another column in another table. The parameter to ForeignKey is a string in the format of 'table.column\_name'. Here, we're saying that the user\_id column of the ratings table refers to the id column of the users table.

    user = relationship("User",
            backref=backref("ratings", order_by=id))

This line establishes a relationship between the Rating and User objects, along with something called a 'backref'. The up-front explanation is hard to grasp, so let's see it in action. Quit your python session and reload it and reconnect (you don't need to remake your tables or re-seed your database).

    >>> r = session.query(Rating).get(1)
    >>> u = r.user
    >>> print u.age
    49
    >>> print u.zipcode
    55105
    >>> print u.ratings
    [ <class Rating>, <class Rating> .... ]
    >>> print u.ratings[0].id
    1
    >>> print u.ratings[0].user_id
    196
    >>> print u.ratings[0].movie_id
    242
    >>> r == u.ratings[0]
    True

The relationship adds an attribute on ratings objects called **user**. This value of this attribute is the same object as if you had queried the database directly for that user. Furthermore, on a user object, there is an attribute named **ratings**. This attribute is a list of all the ratings associated with that user, simultaneously queried from the database.

<div class="note">
**Voodoo Power Hour**: The relationship attribute defined on the Rating class just tells SA how it should construct the _join_ clause of its SELECT statement. It then takes all the results and turns them into the correct objects.
</div>

[Read more](http://docs.sqlalchemy.org/en/rel_0_7/orm/tutorial.html#building-a-relationship) about [SA relationships](http://docs.sqlalchemy.org/en/rel_0_7/orm/relationships.html), then convince yourself that it somehow is magically updating the database correctly. Try detaching a rating from a user and reattaching it to a different user, and monitor how the database updates. 

When you're done with that, add the other half of the relationship to the Movie object. Use the SA [association object pattern](http://docs.sqlalchemy.org/en/rel_0_7/orm/relationships.html#association-object). Use your Rating class as your association object.

Chapter 2: In Which We Weave Threads
------------------------------------
Recall when we integrated sqlite3 directly with our Flask app, we had to do some shenanigans with the **@before\_request** and **teardown_request**, along with the special global object **g** before we could use our database. This is because of something called _threading_.

Threads are a mechanism for concurrency, a short description is that the program makes multiple copies of itself (each copy is called a thread) to support servicing multiple clients (you'll never have just _one_ web user). The individual threads operate independently for the most part, but they share some variables between them. Great care must be taken to ensure that one the threads do not clobber the variables while others are accessing it. So without _locking_ mechanisms, global variables are not considered _thread-safe_.

In the previous exercise, the **g** variable had a hidden locking mechanism on it, so we were safe to put our database connection handle on it and use it with impunity.

SQLAlchemy's primary use is with web applications, or more generally, multi-user applications, and so they would be remiss if they did not include a mechanism which guaranteed thread-safety. In SA, there is something called a scoped\_session. How it works is somewhat beyond the scope of this tutorial, and in fact, most programmers in general. For now, simply _trust_ that it takes care of our threading problems for us. Here is how we use it.

First, change the import line in your model.py to include the scoped\_session function.

    from sqlalchemy.orm import sessionmaker, scoped_session

Next, let's take the contents of the **connect** function and _move them outside the function_.

    from sqlalchemy.orm import sessionmaker, scoped_session

    engine = create_engine("sqlite:///ratings.db", echo=False)
    session = scoped_session(sessionmaker(bind=engine,
                                          autocommit = False,
                                          autoflush = False))

    Base = declarative_base()
    Base.query = session.query_property()

We'll turn the 'echo' parameter to create\_engine to False, and we can now remove the connect() function entirely. Right now, you might be thinking _aaaaargh what does any of this mean how does this work I'm going to quit and become a hog farmer that seems easier_. Two points:

1. Hog farming is really hard. Like, _really_ hard.
2. How it works is unimportant. They're simply lines you _must_ type in to use SA's scoped\_session mechanism if you want to use your app in a multi-threaded app.

You don't have to commit this to memory. You just have to remember it exists. For the purposes of this tutorial, I just copied it [straight from a Flask documentation page](http://flask.pocoo.org/docs/patterns/sqlalchemy/). That's okay, and you'll do this for a lot of things. What's important is knowing what you copied and why you copied it. SA is complex enough that you could spend days trying to understand how that works. It's an interesting mechanism, but ultimately, you have to decide that you've seen enough and move on.

There is a side effect of this change. You no longer need to instantiate the Session class, as it doesn't exist. It's replaced with a session _object_ that is somehow _always connected_. On top of that, this is safe to use this session directly without explicitly connecting to the database:

    (env)Meringue:ratings2 chriszf$ python -i model.py
    >>> u = session.query(User).get(1)
    >>> u.id
    1
    >>> u.age
    10

Notice, we didn't have to connect. We can just start querying the session directly. Cool beans.

Chapter 3: In Which We Tie Things To a Flask
--------------------------------------------
So now we're ready to build the Flask portion of the app. We'll start simply, making a file _judgement.py_. To alleviate fears that you need to know everything, we will go ahead and admit that we are copying everything straight out of the [flask homepage](http://flask.pocoo.org/).

    from flask import Flask
    app = Flask(__name__)

    @app.route("/")
    def hello():
        return "Hello World!"

    if __name__ == "__main__":
        app.run()

Next we'll modify it to include the following things because we _always_ need them:

* rendering templates
* our model
* access to the 'request' object (for forms)
* the ability to redirect
* turn on debug mode

We'll also change the 'hello' view to be called index (just by convention):

    from flask import Flask, render_template, redirect, request
    import model

    @app.route("/")
    def index():
        return "Hello world!"

    if __name__ == "__main__":
        app.run(debug = True)

Next, we'll modify the view to query all our users and list them:

    @app.route("/")
    def index():
        user_list = model.session.query(model.User).all()
        return render_template("user_list.html", users=user_list)

Make a 'templates' directory, and add a user\_list.html file to it:

    <html>
    {% for user in user_list %}
    <h2>User {{ user.id }}, age {{ user.age }} has {{ len(user.ratings) }} ratings</h2>
    {% endfor %}
    </html>

Start your app by running:

    python judgement.py

And access it by going to [http://localhost:5000/](http://localhost:5000/) in your browser.

By switching to SA, we've eliminated a good deal of boilerplate code that was necessary to interact with our database. Instead, we can directly use objects and their attributes without worry about how to query for them.

###Your mission, should you choose to accept it
Is to build out some CRUDL-style views for our User and Ratings objects. Here are some use cases:

* We should be able to create a new user (signup)
* We should be able to log in as a user
* We should be able to view a list of all users
* We should be able to click on a user and view the list of movies they've rated, as well as the ratings
* We should be able to, when logged in and viewing a record for a movie, either add or update a personal rating for that movie.

Do these, then move on to [step 3: judgement](judgement3.html).

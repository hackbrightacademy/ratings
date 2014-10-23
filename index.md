Judgemental Eye: Being a Walkthrough on Building a Movie Rating App
===================================================================
<img width="690px" src="http://art.penny-arcade.com/photos/217529237_jw3tg-L-2.jpg" />

Having spent so much time on [Tipsy](http://chriszf.github.com/tipsy), we should feel fairly comfortable building an app-which-is-like-a-blog from scratch. Scratch here is relative term. We used [sqlite](http://sqlite.org) for our database, writing our own queries, but used [Flask](http://flask.pocoo.org) for its web server and templating engine.

We're going to move on, building a more complex application than before. This time, we're going to use a concept called 'Machine Learning' to teach a computer how to predict things about a human's tastes.

In addition, we're going to remove ourself one layer further from the database using something called an [ORM](http://en.wikipedia.org/wiki/Object-relational_mapping). In the third part of the Tipsy tutorial, we took our data dictionaries and turned them into classes, changing database-access functions into class methods, in an effort to organize our code.

In 2003, [Martin Fowler](http://en.wikipedia.org/wiki/Martin_Fowler) documented a technique called "[Active Record](http://books.google.com/books?id=FyWZt5DdvFkC&lpg=PA1&dq=Patterns%20of%20Enterprise%20Application%20Architecture%20by%20Martin%20Fowler&pg=PT187#v=onepage&q=active%20record&f=false)", a scheme which can be diagrammed like so:

    Table  <->  Class
    Column <->  Attribute
    Row    <->  Instance

In essence, a table definition is more or less equivalent to a class definition. Each column can be thought of as an attribute or property of that class. Each row is also analogous to an instantiation of the class. The analogy isn't perfect, but it serves us well enough. The analogy allows us to construct software that, through the magic of introspection, can automatically write and execute SQL queries for us _without_ the programmer having to stop and think about the sql required to accomplish a task. Here's an example. Given the following sql:

    create table Users 
        (id int primary key not null autoincrement,
         email varchar(64),
         password varchar(64));

Here is how you might set up the class:

    class User(object):
        def __init__(self, id, email, password):
            self.id = id
            self.email = email
            self.password = password

        @classmethod
        def get_by_id(cls, id):
            c = db.cursor()
            c.execute("select * from Users where id = ?", (id,))
            row = c.fetchone()
            return cls(row[0], row[1], row[2])

        def change_password(self, password):
            c = db.cursor()
            query = "update Users set password=? where id=?"
            result = c.execute(query, (password, self.id))
            db.commit()
            return result.lastrowid == self.id

And so here's how you would update a user's password:

        chriszf = User.get_by_id(5)
        chriszf.change_password("mynewpassword")

There's nothing wrong here yet, but if we wanted to be able to update the User's email address as well, we start having to write significant amounts of repetitive code.

An ORM provides us with a slightly different workflow. Instead of writing a bunch of code to handle sql, it instead _peeks_ at your class definitions and uses them to _generate_ appropriate sql. Our **User** class definition changes:

    class User(Base):
        __tablename__ = "Users"
        id = Column(Integer, primary_key=True)
        email = Column(String)
        password = Column(String)

Given this, our ORM can _deduce_ the original schema we generated earlier. The generation of the sql schema can be left to the software. Furthermore, our previous example of changing a user's password can be done as follows:

    chriszf = db.query(User).get(5)
    chriszf.password = "mynewpassword"
    db.commit()

The change\_password function no longer exists in that form; it's existence is obviated as we can access columns directly as if they were object attributes, as long as we _commit_ the database after every modification to an object. Overall, the amount of overhead code required to store data for an app dropped precipitously when ORMs first appeared, allowing lone programmers to single-handedly build a full-stack application in such short time periods.

Chapter 0: In Which We Choose our Tools
---------------------------------------
Let's start by cloning the repository from [github](https://github.com/chriszf/ratings). 

First, we'll choose our ORM.

Just kidding, the choice has been made for you: you will use [sqlalchemy](http://sqlalchemy.org).

There are other ORMs out there, each implementing the different ideas in Fowler's book slightly differently. We simplify the field by choosing sqlalchemy. The other primary competing ORM is the one that is bundled with [Django](https://docs.djangoproject.com/en/dev/topics/db/queries/). The one restriction is that it _cannot_ be used outside of Django, so we won't consider it here.

We'll continue to use Flask because it is suitable for our app, and we'll continue to use Python because I'm feeling generous, but we'll teach two new tools to help us out with using both: virtualenv and pip.

You may have already seen pip, the python package installer. You find the name of the package you want, and type in

    pip install package-name

To find the correct package name to use with pip, you might try to find the package in question on [crate.io](https://crate.io/), a package index. My usually methodology is, if I wander across a webpage that says, "Use the beautiful soup package to parse html", I just try

    pip install beautifulsoup

And it usually works out.

If you try this now, you'll get a series of scary looking warnings followed by a 'permission denied' error. For the most part, you can ignore warnings. They're simply that you _might_ be doing something wrong, which is always the case when you're a professional, so you can get comfortable letting them scroll by.

Errors, on the other hand, are a different beast. They can't be ignored: something is wrong, we can proceed no further.

When using pip (or its predecessor, easy\_install), you'll find that the default usage, installing _any_ package at all results in a 'permission denied' error. This is because of the way unix-like operating systems are laid out. Let's look at the folder structure of a typical unix system.

    /            <-- Top level of the file system.
    /usr
    /usr/local   <-- Where python lives
    /lib
    /home
    /home/student                    <-- Where your files live
    /home/student/fall2012/ratings   <-- Where your project lives

Your files live under /home/student, and you're free to do whatever you like with those. Unfortunately, python lives in /usr/local, because it's a program that _everyone_ using your machine can use. (Remember, a unix machine is by default a multi-user machine. It only _looks_ like it's a single-user experience). To prevent you from messing with a shared program, you are prevented from writing to /usr/local, although reading from it is no problem.

It would be difficult indeed if we could not install new packages at all without summoning the super-user to grant us access, but this is how development went for a long time on multi-user unix systems. Naturally, someone has devised a way around this, called virtualenv.

Virtualenv installs a personal version of python in the directory where your project lives. This python is 'sandboxed', as you are free to do whatever you like with it with no consequences for other users. Go into the folder you cloned from github and type the following.

    virtualenv env --no-site-packages

It should greet you with a success message shortly. This creates a 'virtual environment', your sandboxed python installation in the folder /home/student/fall2012/ratings/**env**. If you ls that directory, you'll find a 'bin' directory, amongst other things. Inside that bin directory is a copy of python.

You can't run it just yet. If you type in 'python' right now, you'll get the standard system python, and not your copy. You can verify this by typing

    which python

This command tells you exactly which copy of python you'll run when you type python into the shell. You have to trick your shell into preferring your copy first, by _activating_ the virtual environment. From the _ratings_ directory, type in

    source env/bin/activate

This runs a script, _env/bin/activate_, that does all the trickery for you. If you type in the __which python__ command again, you'll find that it reports something different. You'll also notice that your shell prompt has an (env) prepended to it, to indicate you're running inside a virtual environment. You can deactivate any time by typing

    deactivate

But don't do this yet, we're going to be working on this project, so we might as well stay in it. Now, for the real reason we went through this process. Type in

    pip install flask

This time, everything should work and you'll be greeted with success. Watch the warnings carefully, and look for a success or failure message at the bottom.

**Now is an appropriate time to give someone a high five**.

Before we go installing things all willy-nilly, let's first install the packages that are required for this project. You'll find a file, requirements.txt in your cloned project directory. This file contains a list of all the packages we'll need. Right now, there are only a few. We could install them one by one by typing in a pip command for each, but we can also install the entire list:

    pip install -r requirements.txt

Awesome.

Chapter 1: In Which We Investigate Our Data
-------------------------------------------
The dataset we'll be using is something called the [MovieLens 100k](http://www.grouplens.org/node/73) dataset. It consists of 100,000 ratings of 1,700 movies from 1,000 users. We'll mine this data for correlations, but first we need to know what it looks like.

The data has already been unpacked for you in the *seed\_data* directory. Take a look now, the files of note are

* README
* u.data
* u.item
* u.user

Spend a little bit trying to decipher the files before moving on. It will make it easier to remember that in this dataset, 'items' are movies.

### u.data
According to the readme, u.data looks like this

    user_id     movie_id     rating     timestamp

The data is in tabular format, the first column being a user id, the second being a movie id, the third being a rating (from 1 to 5). All three columns are integers. The fourth is a timestamp, also an integer, the number of seconds from January 1, 1970.

### u.item
This data is also tabular -- there are too many columns to list here, so refer to the readme. The gist is that each line in this file has some movie id, and a bunch of attributes of that movie, including url, release date, imdb url, etc.

### u.user
This file is information about the user, this time separated by vertical bars:

    user_id | age | gender | occupation | zip_code

Stop here and think about how these three files constitute a model. I'll wait.

<div class="spoilers">
If you caught the copious hints, you should be thinking that each of these files is a table in a database. Every one of the columns in the file is the same as a database column. To reconstruct an entire record, _who_ rated _what_ movie, we first go to the u.data table to get a user\_id and a movie\_id. We take those numbers and search their respective files for the row id that matches, then glue all three rows together.
</div>

Chapter 2: In Which We Build Our Database
-----------------------------------------
Okay, so our data is in files and we need to put them into database tables. Great, we'll start writing a schema. Identify the tables we'll need to make, and sketch out the schema. Right now, we can throw out any genre data. We'll also add authentication data to the user schema, adding both an email and password, while making demographic information optional. Sketch out a rough schema as well as any relationships between the tables (has many, belongs to, etc).

Going by our files, we can come up with the following skeleton

<div class="spoilers">

    User
    id: integer
    age: integer
    gender: string
    zip_code: string (technically zip codes aren't numeric)
    email: optional string
    password: optional string

    Movie:
    id: integer
    name: string
    released_at: datetime
    imdb_url: string

    Rating:
    id: integer
    movie_id: integer
    user_id: integer
    rating: integer

    A user has many ratings
    A rating belongs to a user
    A movie has many ratings
    A rating belongs to a movie
    A user has many movies through ratings
    A movie has many users through ratings

</div>

Now, to write the sql.

Well, not so fast. Writing schemas is hard work. Not only that, it's tedious work. It needs to be done, but it gets tricky remembering where all the parens and optional words go. No, we're better than that, we won't stoop to their level. We'll write _code_ that writes our schemas for us.

First, ls in your project directory. You should see a model.py file. Note the conspicuous absence of a database file. Not there? Good. We'll begin the alchemy.

SQLAlchemy is powerful software, and the process it uses by which it transmutes python into sql and back is indeed alchemical. While it would be most excellent for you to *understand* exactly what's happening, at this stage we just need to be able use it reliably. Trust the incantations, then open your model.py file, and we'll start building our User model.

We're going to be doing things backwards from the first time around. We'll start with our User class without an \_\_init\_\_ method:

    class User(Base):
        pass

So far, the only thing out of the ordinary is the inheritance from a class named 'Base'. This is how we declare a class to be managed by SQLAlchemy. The Base class is defined on line 5:

    Base = declarative_base()

The Base class is simply required for SQLALchemy's magic to work. Now, we'll start adding column definitions. We'll add the following lines to the User class:

    class User(Base):
        __tablename__ = "users"

        id = Column(Integer, primary_key = True)
        email = Column(String(64), nullable=True)
        password = Column(String(64), nullable=True)
        age = Column(Integer, nullable=True)
        zipcode = Column(String(15), nullable=True)

We'll go over it line by line, but try not to find the deeper reasons for this syntax: this is a fairly non-standard use of python class attributes. It's allowed by the language definition, but ultimately, these lines we just added are SQLAlchemy specific and only make sense in that context. It's good to remember them, but it's equally good to remember how to look them up.

The first line

    __tablename__ = "users"

Simply informs SQLAlchemy that instances of this class will be stored in a table named _users_.

The next,
    
    id = Column(Integer, primary_key = True)

Tells SQLAlchemy to add a column to the table named 'id'. It will contain an integer, and be the 'primary key' for our table: it will uniquely identify every row in the table. The next line contains something slightly different

    email = Column(String(64), nullable=True)
        
This behaves as you'd expect, with the exception of the 'nullable=True' part. That tells SQLAlchemy (and thus, SQLite) that this column is optional, it's allowed to be null/None. Since our ml-100k dataset is anonymized, we won't have any email addresses for any of the users we're given. However, to simplify things, we'll be using the same table to store _new_ users who can log in via email, so we need to make the field available for them. An alternative solution would be to make the email column required, and generate fake emails for the anonymous users.

The remaining columns follow in a similar fashion.

The word 'String' is not a built-in python class (that one is 'str'), nor is Integer (int, respectively). These are the SQLAlchemy-managed versions of the same datatypes. You'll find that they're imported from sqlalchemy.orm, at the top of the file. SQLAlchemy has a number of other data types as well, including datetimes, booleans, floats, etc., all imported from the same place.

The last thing of note is that there is no \_\_init\_\_ function. SQLAlchemy's Base class provides one for you that uses keyword arguments when initializing objects. It's required for some of the magic to work, so don't add one unless you've consulted the SQLAlchemy documentation on doing so.

So far, we haven't seen anything special happen, except some of our python was written weirdly. In our terminal window with the activated virtual environment, (reactivate it by going to your project directory and typing **source env/bin/activate** if you somehow lost it), run your model.py with the -i option:

    python -i model.py

In your interactive python shell that results, type in

    engine = create_engine("sqlite:///ratings.db", echo=True)

Now, open a second terminal window and go to your project folder, do an _ls_ to verify that ratings.db does not exist.

In your first window, type the following, and something that appears to be a sql table schema will scroll by. 


    Base.metadata.create_all(engine)

Back in your second window, do another _ls_ You should see a ratings.db file. Invoke sqlite on this file, and investigate:

    Meringue:ratings2 chriszf$ sqlite3 ratings.db
    SQLite version 3.7.7 2011-06-25 16:35:41
    Enter ".help" for instructions
    Enter SQL statements terminated with a ";"
    sqlite> .mode columns
    sqlite> .header on
    sqlite> .tables
    users
    sqlite> .schema users
    CREATE TABLE users (
            id INTEGER NOT NULL, 
            email VARCHAR(64), 
            password VARCHAR(64), 
            age INTEGER, 
            zipcode VARCHAR(15), 
            PRIMARY KEY (id)
    );
    sqlite> 

<center>
Mind = **blown**

<img src="http://tifr.us/storage/post-images/Tim-Eric-Mind-Blown-__SQUARESPACE_CACHEVERSION=1316658161000.gif">
</center>

Quit both sqlite3 and python then delete your _ratings.db_ file. Create a similar class for Movies and Ratings. Refer to the [sqlalchemy tutorial](http://docs.sqlalchemy.org/en/rel_0_7/orm/tutorial.html) if necessary. When you're done, repeat the process of running **Base.metadata.create\_all()** to create your tables. Reopen your sqlite3 database in your second window, making sure to turn headers on and switching the mode to columns.

<div class="spoilers">
SQLAlchemy uses a mechanism called 'introspection' where it can look inside a class, identify the attributes on it and what type they are, then use that to construct a sql schema.

We simply have to _declare_ class attributes in a particular way on classes derived from the _Base_ class provided for SQLAlchemy to do its introspection magic.
</div>

Chapter 3: In Which We Populate Our Tables
------------------------------------------
In SQLAlchemy parlance, we've created an engine. The terminology here is arbitrary: an 'engine' refers to an object that we use to connect to a database engine. The _engine_ itself is not an engine, just a method to connect to one. This is not unlike calling **sqlite3.connect()** and using the object that was returned as a connection.

After the connection, we need a 'handle' to interact with the database. In SQLAlchemy, this is called a 'session'. The session is analogous to the sqlite3 _cursor_ we have been using. Add the following lines to the top of your model file, after the other imports:

    from sqlalchemy.orm import sessionmaker

    ENGINE = None
    Session = None

And add the following function before the main function:

    def connect():
        global ENGINE
        global Session
        
        ENGINE = create_engine("sqlite:///ratings.db", echo=True)
        Session = sessionmaker(bind=ENGINE)

        return Session()

Here, _Session_ is actually a class generated by SQLAlchemy, using the 'sessionmaker' function. This pattern is particular to SQLAlchemy and actually atypical python. The Session class describes how to interact with the database, but you can't use it directly. You need to instantiate sessions. At the end of **connect**, we do exactly that and return the instance, but any time you need a session _later_, you can just do

    session = Session()

For now, load your model with 

    python -i model.py

Once you're in, type the following to create a session:

    >>> session = connect()

In your sqlite window, insert a new row into your users table:

<div class="spoilers">

    INSERT INTO users VALUES (null, "c@hackbrightacademy.com", "mypass", 29, "94103");
</div>

Now, we will transmute SQL into Python. First, query to see your shiny new record in sqlite:

    sqlite> select * from users;
    id          email                    password    age         zipcode   
    ----------  -----------------------  ----------  ----------  ----------
    1           c@hackbrightacademy.com  mypass      29          94103     

Switch to your python window and type the following:

    >>> c = session.query(User).get(1)
    >>> print c.email
    c@hackbrightacademy

The '1' in the first line is the id of the User we want to get from our table. If your database has a different id, use that instead. Let's update my password to be something more secure:

    >>> c.password = "somethingmoresecure"

Now, let's query the database to see if that worked:

    sqlite> select * from users;
    id          email                    password    age         zipcode   
    ----------  -----------------------  ----------  ----------  ----------
    1           c@hackbrightacademy.com  mypass      29          94103     

Nothing! What gives? Well, like when we did raw sql (and not dissimilar to git), we need to commit data after we've modified it. In python:

    >>> session.commit()

And query again:

    sqlite> select * from users;
    id          email                    password    age         zipcode   
    ----------  -----------------------  ----------  ----------  ----------
    1           c@hackbrightacademy.com  somethingm  29          94103     

SQLAlchemy took our python and _wrote_ the appropriate SQL update query for us behind the scenes. This is a powerful idea, because now we can write programs, only worrying about the classes and data we're interested in, and not how to write the SQL we need to save it somewhere.

<center>
**Once more, for effect:**

<img src="http://tifr.us/storage/post-images/Tim-Eric-Mind-Blown-__SQUARESPACE_CACHEVERSION=1316658161000.gif">

</center>

### Reversing Directions
We inserted data in SQL, then got it back out on the python end, where we could update it. Now, let's do the reverse, where we insert data in from python. Let's make a record for Charles.

    >>> charles = User(email="charles@hackbrightacademy.com", password="notsecure", age=25, zipcode="94103")

If we query the database, we get nothing:

    sqlite> select * from users;
    id          email                    password    age         zipcode   
    ----------  -----------------------  ----------  ----------  ----------
    1           c@hackbrightacademy.com  somethingm  29          94103     

Right, we have to commit first. Actually, we have to do more than commit. Right now, we have a _User_ object that we created in python, but that isn't reflected in the database immediately. There are times when we want to do exactly this, so SQLAlchemy forces us to be _explicit_ when we want to insert something into the database as well. We do this by _adding_ an object to our session. Here, the github parallel is particularly strong.

    >>> session.add(charles)
    >>> session.commit()

Now, in sqlite, one more time:

    sqlite> select * from users;
    id          email                    password    age         zipcode   
    ----------  -----------------------  ----------  ----------  ----------
    1           c@hackbrightacademy.com  somethingm  29          94103     
    2           charles@hackbrightacade  notsecure   25          94103     

Now that our object has been 'added' to the database, it is being tracked, and if we need to update it, we only need to commit after modifying it:

    # In python
    >>> charles.password = "moresecure"
    >>> session.commit()

    -- in sqlite
    sqlite> select * from users where id=2;
    id          email                    password    age         zipcode   
    ----------  -----------------------  ----------  ----------  ----------
    2           charles@hackbrightacade  moresecure  25          94103     

Let's do one more thing. We've so far relied on sqlite to assign unique ids to our users. We can force users to have a particular id.

    >>> david = User(email="d@hackbrightacademy.com", password="password", age=26, zipcode="94103")
    >>> david.id = 5
    >>> session.add(david)
    >>> session.commit()

Then, querying for his record in sqlite:

    sqlite> select * from users where email='d@hackbrightacademy.com';
    id          email                    password    age         zipcode   
    ----------  -----------------------  ----------  ----------  ----------
    5           d@hackbrightacademy.com  password    26          94103     

Experiment with adding, committing, and querying to make sure you understand how data goes into sqlite through python, and how to get it back out. Add new records on both the sqlite and python sides, and use **.get()** to get them back out. Change some fields, then commit them back and see how the columns get updated. Do this for all three tables, then get ready to wipe them out.

A New Challenger Has Appeared
-----------------------------
Now we know how to insert single rows into the database, we have to _bulk insert_ a bunch of our movie data. You'll find a file, seed.py, which contains a rough outline of what needs to happen. You'll need to open up the three files corresponding to the three tables, read each row in, parse it, then insert it into the database using our SQLAlchemy object interface.

We've included the [python csv](http://docs.python.org/2/library/csv.html) module, which may help you out in the process. You'll find examples of how to use it at the bottom of the link. Your general strategy should be as follows:

1. open a file
2. read a line
3. parse a line
4. create an object
5. add the object to a session
6. commit
7. repeat until done

Each of the files is formatted slightly differently, so you'll need to write slightly different functions for each.

Parsing titles (removing year of release)
Parsing datetimes

Addendum: Unicode
-----------------
Unicode is kind of tough to grasp. It's a collection of 'code points' that represent all the known characters in use in modern language, whether it's the western alphabet, or Asian kana systems. The concept of code points is really irrelevant to our discussions. The most important thing is that a unicode string is capable of representing any character in any syllabary we have a font for.

The thing is, having this kind of flexibility requires a lot of space. In good, old ascii, letters are any one of 52 numbers, both upper and lower case. Add in other symbols on the keyboard, a few symbols _not_ on the keyboard, and still everything fits in a single byte. Each character only needed a single byte to represent it. A string of 30 characters needed 30 bytes total to store.

With unicode, there are 1,114,112 code points, usually represented by 4 bytes per character. This means in unicode, a 30 character string needs 120 bytes for storage. Generally, unicode is not a good way to _store_ text, although it's a great way to represent text in general.

Typically, you won't need all 1 million code points in any given text, so encodings exist that allow us to store text and optimize for a particular subset of the code points. When we need to share text between components, we need to take our encoded text and decode it back into unicode before sending it back.

In our scenario, a text file is encoded in the 'latin-1' encoding, to allow us to use an accent mark in our movie titles. Our sqlite3 database, on the other hand, expects to receive unicode strings from our python code, so we need to decode from latin-1 back into unicode:

    title = row[3]
    title = title.decode("latin-1")

After this, our 'title' variable is a string that stores data as unicode code points, and can be safely passed off to sqlite3.

Complete this, then move on to [part 2](judgement2.html).

import basem, ../dbm

# No need to manage connections, it will be connected lazily and
# reconnected in case of connection error
let db = Db.init("nim_test")


# Creating schema
db.before """
  drop table if exists users;

  create table users(
    name       varchar(100)   not null,
    age        integer        not null
  );
  """


# SQL with `:named` parameters instead of `?`
db.exec(sql("""
  insert into users ( name,  age)
  values            (:name, :age)
  """,
  (name: "Jim", age: 33)
))


# Conversion to objects, named or unnamed tuples
let rows = db.get(sql"""
  select name, age
  from users
  where age > {10}
  """,
  tuple[name: string, age: int]
)
assert rows == @[(name: "Jim", age: 33)]


# Count
assert db.get_one(sql"select count(*) from users", int) == 1
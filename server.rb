require "sinatra"
require "pg"
require "erb"

configure :development do
  set :db_config, { dbname: "movies" }
end

configure :test do
  set :db_config, { dbname: "movies_test" }
end

def db_connection
  begin
    connection = PG.connect(Sinatra::Application.db_config)
    yield(connection)
  ensure
    connection.close
  end
end


get '/movies' do

  db_connection do |conn|
    @movies = conn.exec("SELECT movies.id, movies.title, movies.year, movies.rating, genres.name, studios.name FROM movies LEFT OUTER JOIN studios ON (movies.studio_id = studios.id) LEFT OUTER JOIN genres ON (movies.genre_id = genres.id) ORDER BY movies.title;")
  end

  erb :'movies/index'
end

get '/movies/:id' do

  db_connection do |conn|
    @movie_info = conn.exec_params("SELECT movies.title, movies.year, movies.rating, genres.name, studios.name FROM movies LEFT OUTER JOIN studios ON (movies.studio_id = studios.id) LEFT OUTER JOIN genres ON (movies.genre_id = genres.id) WHERE movies.id = $1;", [params[:id]])
    @actor_list = conn.exec_params("SELECT cast_members.character, actors.name, actors.id FROM cast_members JOIN actors ON (cast_members.actor_id = actors.id) WHERE cast_members.movie_id = $1;", [params[:id]])
  end

  erb :'movies/show'
end

get '/actors' do

  db_connection do |conn|
    @results = conn.exec("SELECT id, name FROM actors ORDER BY name;")
  end

  erb :'actors/index'
end

get '/actors/:id' do
  db_connection do |conn|
    @indiv_actor = conn.exec_params("SELECT actors.name, cast_members.character, movies.title, movies.id FROM actors JOIN cast_members ON (actors.id = cast_members.actor_id) JOIN movies ON (cast_members.movie_id = movies.id) WHERE actors.id = $1;", [params[:id]])
  end

  erb :'actors/show'
end

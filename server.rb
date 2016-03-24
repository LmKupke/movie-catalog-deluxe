require "sinatra"
require "pg"
require "erb"
require "pry"

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

  if params["query"] != nil
    @title = '%' + params['query'] + '%'
    sql = <<-SQL
    SELECT movies.id, movies.title, movies.year, movies.rating, genres.name, studios.name
      FROM movies LEFT OUTER JOIN studios ON (movies.studio_id = studios.id)
      LEFT OUTER JOIN genres ON (movies.genre_id = genres.id)
      WHERE movies.title ILIKE $1 OR movies.synopsis ILIKE $1;
    SQL
  else

    if params["Order"]== nil
      @order = "movies.title"
    elsif params["Order"]
      @order = "movies.#{params['Order']}"
    end

    if params["page"] == nil
      @page = 0
    elsif params["page"] == "0"
      @page = 0
    elsif params["page"] == "1"
      @page = 1
    elsif
      @page = params["page"].to_i
    end

    sql = <<-SQL
      SELECT movies.id, movies.title, movies.year, movies.rating, genres.name, studios.name
        FROM movies LEFT OUTER JOIN studios ON (movies.studio_id = studios.id)
        LEFT OUTER JOIN genres ON (movies.genre_id = genres.id)
        ORDER BY #{@order} LIMIT 20 OFFSET #{@page};
    SQL
  end

  db_connection do |conn|
    if @title != nil
      @movies = conn.exec_params(sql,[@title])
    else
      @movies = conn.exec(sql)
    end
    @total_amount = conn.exec("SELECT COUNT(title) FROM movies;")
  end
  @total_amount = @total_amount.values.flatten!.first.to_i
  @amount_movie_pgs = @total_amount/ 20
  erb :'movies/index'
end

get '/movies/:id' do

  db_connection do |conn|
    sql = <<-SQL
      SELECT movies.title, movies.year, movies.rating, genres.name, studios.name
      FROM movies LEFT OUTER JOIN studios ON (movies.studio_id = studios.id)
      LEFT OUTER JOIN genres ON (movies.genre_id = genres.id)
      WHERE movies.id = $1;
    SQL

    sql2 = <<-SQL
      SELECT cast_members.character, actors.name, actors.id
        FROM cast_members JOIN actors ON (cast_members.actor_id = actors.id)
        WHERE cast_members.movie_id = $1;
    SQL
    @movie_info = conn.exec_params(sql, [params[:id]])
    @actor_list = conn.exec_params(sql2, [params[:id]])
  end

  erb :'movies/show'
end

get '/actors' do
  if params["query"] != nil
    @actor_query = '%' + params['query'] + '%'
    sql = <<-SQL
    SELECT DISTINCT actors.id, actors.name, COUNT(movies.title) FROM actors
      LEFT OUTER JOIN cast_members ON (actors.id = cast_members.actor_id)
      LEFT OUTER JOIN movies ON (movies.id = cast_members.movie_id)
      WHERE actors.name ILIKE $1 OR cast_members.character ILIKE $1
      GROUP BY actors.id ORDER BY actors.name;
    SQL

  elsif params["query"] == nil
    @page = 0
    if params["page"] == "0"
      @page = 0
    elsif params["page"] == "1"
      @page = 1
    elsif
      @page = params["page"].to_i
    end
    sql = <<-SQL
      SELECT actors.id, actors.name, COUNT(movies.title) FROM actors
      LEFT OUTER JOIN cast_members ON (actors.id = cast_members.actor_id)
      LEFT OUTER JOIN movies ON (movies.id = cast_members.movie_id)
      GROUP BY actors.id
      ORDER BY actors.name LIMIT 20
      OFFSET $1;
    SQL

  end
  db_connection do |conn|
    @total_amount = conn.exec("SELECT COUNT(name) FROM actors;")
    if @actor_query != nil
      @results = conn.exec_params(sql,[@actor_query])
    else
      @results = conn.exec_params(sql,[@page])
    end

  end
  @total_amount = @total_amount.values.flatten!.first.to_i
  @amount_actor_pgs = @total_amount/ 20

  erb :'actors/index'
end

get '/actors/:id' do
  db_connection do |conn|
    @indiv_actor = conn.exec_params("SELECT actors.name, cast_members.character, movies.title, movies.id FROM actors JOIN cast_members ON (actors.id = cast_members.actor_id) JOIN movies ON (cast_members.movie_id = movies.id) WHERE actors.id = $1;", [params[:id]])
  end

  erb :'actors/show'
end

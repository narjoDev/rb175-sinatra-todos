require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists
end

# Render the new list form
get '/lists/new' do
  erb :new_list
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique'
  end
end

# Create a new list
post '/lists' do
  list_name = params['list_name'].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list # address still displays '/lists'...
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

get '/lists/:id' do
  @lists = session[:lists]
  @id = params[:id].to_i
  @list = @lists[@id]
  if (0...@lists.size).cover? @id
    erb :list
  else
    session[:error] = 'The specified list was not found.'
    redirect '/lists'
  end
end

# Edit an existing todo list
get '/lists/:id/edit' do
  @lists = session[:lists]
  @id = params[:id].to_i
  @list = @lists[@id]
  erb :edit_list
end

# Update an existing todo list
post '/lists/:id' do
  list_name = params['list_name'].strip
  id = params[:id].to_i
  @list = session[:lists][id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{id}"
  end
end

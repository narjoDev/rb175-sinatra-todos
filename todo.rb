require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, escape_html: true
end

helpers do
  # Launch School implementation displays _remaining_
  # rather than _done_
  # That seems counterintuitive to me *shrug*
  def todos_done(list)
    list[:todos].count { |todo| todo[:completed] }
  end

  # For now I will follow their lead
  def todos_remaining(list)
    todos_count(list) - todos_done(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def list_complete?(list)
    todos = list[:todos]
    !todos.empty? && todos_done(list) == todos.size
  end

  def list_class(list)
    'complete' if list_complete?(list)
  end

  def sort_lists(lists, &block)
    lists.each.sort_by do |list|
      list_complete?(list) ? 1 : 0
    end.each(&block)
  end

  def sort_todos(todos, &block)
    todos.each.sort_by do |todo|
      todo[:completed] ? 1 : 0
    end.each(&block)
  end
end

def load_list(id)
  list = session[:lists].find { |list| list[:id] == id }
  return list if list

  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique'
  end
end

def error_for_todo(name)
  return if (1..100).cover? name.size

  'Todo must be between 1 and 100 characters.'
end

def next_element_id(elements)
  max = elements.map { |element| element[:id] }.max || 0
  max + 1
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

# Create a new list
post '/lists' do
  list_name = params['list_name'].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list # address still displays '/lists'...
  else
    id = next_element_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# View a single todo list
get '/lists/:id' do
  id = params[:id].to_i
  @list = load_list(id)
  @list_id = @list[:id]
  erb :list
end

# Edit an existing todo list
get '/lists/:id/edit' do
  @id = params[:id].to_i
  @list = load_list(@id)
  erb :edit_list
end

# Update an existing todo list
post '/lists/:id' do
  list_name = params['list_name'].strip
  id = params[:id].to_i
  @list = load_list(id)

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

# Delete a todo list
post '/lists/:id/destroy' do
  id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == id }
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    session[:success] = 'The list has been deleted.'
    redirect '/lists'
  end
end

# Add a new todo to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list
  else
    id = next_element_id(@list[:todos])
    @list[:todos] << { id: id, name: text, completed: false }
    session[:success] = 'The todo has been added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:id/destroy' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed

  # session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post '/lists/:id/complete_all' do
  id = params[:id].to_i
  list = load_list(id)

  list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{id}"
end

require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_remaining(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_lists(lists)
    result = []
    lists.each_with_index do |list, index|
      result << {list: list, index: index}
    end
    
    result.sort_by! {|hash| list_complete?(hash[:list]) ? 1 : 0}
    result.each do |hash|
      yield(hash[:list], hash[:index]) if block_given?
    end
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View all the lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid, nil if name is valid
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Display a single todo list
get "/lists/:id" do |id|
  @list_id = id.to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Edit a list
get "/lists/:id/edit" do |id|
  @list = session[:lists][id.to_i]
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post "/lists/:id" do |id|
  @list_id = id.to_i
  @list = session[:lists][@list_id]
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete a todo list
post "/lists/:id/delete" do |id|
  session[:lists].delete_at(id.to_i)
  session[:success] = "The list has been deleted"
  redirect "/lists"
end

# Return an error message if the todo is invalid, nil if todo is valid
def error_for_todo_name(todo_name)
  if !(1..100).cover?(todo_name.size)
    "Todo must be between 1 and 100 characters."
  end
end

# Add a todo to a list
post "/lists/:list_id/todos" do |list_id|
  @list_id = list_id.to_i
  @list = session[:lists][@list_id]
  todo_name = params[:todo].strip
  error = error_for_todo_name(todo_name)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: todo_name, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i
  
  @list[:todos].delete_at(todo_id)
  session[:success] = "The todo has been deleted."
  redirect "/lists/#{@list_id}"
end

# Check/uncheck a todo item
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i

  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = "The todo has been updated"
  redirect "/lists/#{@list_id}"
end

# Complete all todos in a list
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end
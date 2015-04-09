class ResourcesController < ApplicationController

  # why are we defining the user in terms of the session??
  before_action :find_user, only: [:index, :new, :create, :destroy]
  before_action :find_resource, only: [:update]

  def index
    @resources = @user.resources
  end

  def newwant
    @resource = Resource.new
    @user = User.find(session[:user_id])
    categories = ['bike', 'vehicle', 'social', 'pet', 'housing']
    existing_categories = []
    if @user.wants_bike == true
      existing_categories << "bike"
    end

    if @user.wants_vehicle == true
      existing_categories << "vehicle"
    end

    if @user.wants_social == true
      existing_categories << "social"
    end

    if @user.wants_pet == true
      existing_categories << "pet"
    end

    if @user.wants_housing == true
     existing_categories << "housing"
   end

   @available_resources = categories - existing_categories
 end

 def newhas
  @resource = Resource.new
  @user = User.find(session[:user_id])
  categories = ['bike', 'vehicle', 'social', 'pet', 'housing']
  existing_categories = []
  if @user.has_bike == true
    existing_categories << "bike"
  end

  if @user.has_vehicle == true
    existing_categories << "vehicle"
  end

  if @user.has_social == true
    existing_categories << "social"
  end

  if @user.has_pet == true
    existing_categories << "pet"
  end

  if @user.has_housing == true
   existing_categories << "housing"
 end

 @available_resources = categories - existing_categories

end

def show
  @user = User.find params[:user_id]
  @resource = Resource.find params[:id]
  @session_user = User.find session[:user_id]
  @reviews = @resource.reviews
  @match = two_users_matched @user, @session_user
end

def edit
  @user = User.find params[:user_id]
  @resource = Resource.find params[:id]
end

def create
  if params["resource"]["category"] == ""
    flash[:alert] = "Please enter a resource."
    redirect_to :back
  else

    has_category = "has_#{resource_params[:category]}"
    wants_category = "wants_#{resource_params[:category]}"
    @resource = Resource.new resource_params
    @has_resource = User.where(has_category.to_sym => true) - [@user]
    @wants_resource = User.where(wants_category.to_sym => true) - [@user]
    # don't allow user to save identical resources
    unless resource_exists @user, @resource
      if @resource.save
        # update_user_table @user, @resource, "add"
        # below will update category booleans in users table
        if resource_params[:has] == "true"
        #creating joint table row + scoring interest overlap
        @wants_resource.each do |user|
          if user.location == @user.location
            location_weight = 1
          else
            location_weight = 0.75
        #end of scoring algo
      end

      ResourcesUser.create(user_wants_id:user.id,user_has_id: @user.id,
        score: (user.interests & @user.interests).length*location_weight/user.interests.length, resource_category: resource_params[:category], resource_id: @resource.id)
    end
    @user.update_attribute(has_category.to_sym, true)
  else
        #creating joint table row + scoring interest overlap
        @has_resource.each do |user|
          if @user.location == user.location
            location_weight = 1
          else
            location_weight = 0.75
        #end of scoring algo
      end
      
      ResourcesUser.create(user_has_id:user.id,user_wants_id: @user.id,
        score: (@user.interests & user.interests).length*location_weight/@user.interests.length, resource_category: resource_params[:category], resource_id: @resource.id)
    end
    @user.update_attribute(wants_category.to_sym, true)
  end
        #end of updating category booleans in users table
        if resource_params[:has] == "true"
          redirect_to newhas_user_resource_path @user
        else
          redirect_to newwant_user_resource_path @user
        end
      else
        flash.now[:alert] = "Please correct the following input errors"
        render :new
      end
    else
      flash.now[:alert] = "You have already created that resource"
      render :new
    end
  end
end

  # all you can udpate is the description
  # or you can just delete it
  def update
    @user = User.find params[:user_id]
    @resource.update_attributes(description: params[:resource][:description])
    if @resource.save
      flash[:notice] = "Shareable description updated"
      redirect_to show_user_resource_path(@user, @resource)
    else
      flash.now[:alert] = "Something went wrong"
      render :edit
    end
  end

  def destroy
    resource = Resource.find params[:id] # No need for instance var here
    # is this check even going to be necessary?
    # when will one user be able to directly examine another user's resources?
    has_category = "has_#{resource.category}"
    wants_category = "wants_#{resource.category}"
    if session[:user_id] != resource.user_id
      flash[:alert] = "You are not authorized to delete this itinerary"
      redirect_to user_home_path
    else
      # below will update category booleans in users table
      if resource.has
        @user.update_attribute(has_category.to_sym, false)
        #deleting joint table entries when a has is removed
        @resourceusers = ResourcesUser.where(resource_category: resource.category).where(user_has_id: @user.id)
        @resourceusers.destroy_all
      else
        @user.update_attribute(wants_category.to_sym, false)
        #deleting joint table entries when a want is removed
        @resourceusers = ResourcesUser.where(resource_category: resource.category).where(user_wants_id: @user.id)
        @resourceusers.destroy_all
      end
        #end of updating category booleans in users table
      # update_user_table @user, resource, "remove"
      resource.destroy
      redirect_to user_home_path
    end
  end

  private

  def two_users_matched user1, user2
    # gather the relevant data entries.  there's probably a better way to do this
    resource_matches = (ResourcesUser.where(user_wants_id:user1.id, user_has_id:user2.id) +
      ResourcesUser.where(user_wants_id:user2.id, user_has_id:user1.id))
    # start by assuming a match exists
    match = true
    match = false if resource_matches.empty?
    resource_matches.each do |resource_match|
      # unless like_accept = false
      match = false unless resource_match.like_accept
    end
    return match
  end

  def resource_exists user, new_resource
    unless user.resources.empty?
      user.resources.each do |resource|
        if resource.category == new_resource.category && resource.has == new_resource.has
          return true
        else
          return false
        end
      end
    else
      return false
    end
  end

  def find_user
    @user = User.find session[:user_id]
  end

  def find_resource
    @resource = Resource.find params[:id]
  end

  def resource_params
    params.require(:resource).permit(:user_id, :category, :has, :description)
  end

end

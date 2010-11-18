class UsersController < ApplicationController
 
  requires_authentication :except => [:support, :contact_us, :sendsupport, :edit, :edit_form, :update, :changePassword, :subagents, :subagents_form, :addagents], :using => :webservice_access, :realm => 'Webservice access only'
 
  layout "builder", :only => [:support, :edit, :subagents]
  # GET /users
  # GET /users.xml
  def index
    @users = User.find(:all)
 
    respond_to do |format|
      format.html # index.html.erb
      format.xml { render :xml => @users.to_xml }
    end
  end
 
  # GET /users/new
  def new
    @user = User.new
  end
 
  # POST /users
  # POST /users.xml
  def create
    @user = User.new(params[:user])
 
    respond_to do |format|
      if @user.save
        flash[:notice] = 'User was successfully created.'
        format.html { redirect_to user_url(@user) }
        format.xml { head :created, :location => user_url(@user) }
      else
        format.html { render :action => "new" }
        format.xml { render :xml => @user.errors.to_xml }
      end
    end
  end
 
  # ---------------------------------------------------------------------------
 
  # GET /users/1
  # GET /users/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml { render :xml => @user.to_xml }
    end
  end
 
  # GET /users/1;edit
  def edit
    @user_detail = UserDetails.find_by_domainname(current_user.name)
  end
 
  def update
    old_email = current_user.user_detail.email
    ud = current_user.user_detail
    ud.email = params[:user][:email] if params[:user]
 
    if current_user.update_attributes(params[:user]) && ud.save
      if old_email.to_s == params[:user][:email].to_s
        flash[:message] = 'User successfully updated.'
      else
        current_user.update_user_contactus_mail(current_site, old_email)
        current_site.pages.find_by_url('career.html').update_attributes(:content => render_to_string(:partial => "career")) unless current_site.pages.find_by_url('career.html').nil?
        current_site.pages.find_by_url('contactus.html').update_attributes(:content => render_to_string(:partial => "contactus"))
 
        flash[:message] = 'User successfully updated. Since your Email has changed, you should re-pulish the site.'
      end
    else
      errors = current_user.errors.full_messages + current_user.user_detail.errors.full_messages
      errors = ["there was a problem updating your account"] if errors.blank?
 
      flash[:message] = "Sorry, #{ errors.join(", ") }."
    end
 
    redirect_to edit_user_path(current_user)
  end
 
  def changePassword
    return unless params[:user]
 
    @user = current_user
    @key = EzCrypto::Key.with_password "webbuilderftp", ""
 
    password, confirmation = params[:user][:password], params[:user][:password_confirmation]
 
    if password.blank? || confirmation.blank?
      flash[:notice] = "Please fill in all the fields. Try Again!"
 
    elsif confirmation != password
      flash[:notice] = "Passwords do not match. Please Try Again!"
 
    else
      params[:user][:ftp_password] = @key.encrypt params[:user][:password]
 
      if @user.update_attributes(params[:user])
        flash[:notice] = 'Password was changed.'
      else
        flash[:notice] = 'Error Updating the Password. Please try again.'
      end
    end
  end
 
  def subagents
    # render template
  end
 
  def addagents
 
    j, i = 1, params[:no_of_agents].to_i
    b = [params[:subagents_1],params[:subagents_2],params[:subagents_3],params[:subagents_4]]
 
    if b.all?(&:blank?)
      SubAgent.destroy_all "user_id = #{current_user.id}"
      flash[:subagent_notice]='Sub Agents are deleted'
      redirect_to :action => "subagents_form"
      return
    end
 
    repeted_val = b.select{|e| b.index(e) != b.rindex(e) }.uniq
 
    if repeted_val and repeted_val.to_s != ''
      flash[:subagent_notice]='Partner Agent Key should be unique and not empty'
      redirect_to :action => "subagents_form"
    elsif b.include?(current_user.agent_id)
      flash[:subagent_notice]='Invalid Partner Agent Key!'
      redirect_to :action => "subagents_form"
    else
      if agent_info(b)
        SubAgent.destroy_all "user_id = #{current_user.id}" if !current_user.sub_agents.nil?
        i.times do
          @bval = eval("params[:subagents_"+ j.to_s+"]")
          agents = SubAgent.new
          agents.agent_id = current_user.agent_id
          agents.sub_agent_id = eval("params[:subagents_"+ j.to_s+"]")
          agents.user_id = session[:user_id]
          agents.save
          j=j+1
        end
 
        partners = current_user.subagents
 
        if current_site.template.name == 'Team Layout'
          current_site.pages.each do |p|
            case p.title
            when 'Our Agents', 'Our Offices', 'Careers', 'Local Services',
                 'Associate Profile', 'Amenities', 'Property Description'
              p.show = 0
            else
              case p.url
              when 'aboutus.html'
                p.title = "About Us"
              when 'contactus.html'
                p.title = "Contact Us"
                p.content = "<div id='textcontent'><iframe src='http://c21wwcrest.idx.net/c21_contact_agent.php?cid=#{current_user.company_id}&mode=agents&office_id=#{current_user.office_id.to_s}&agent_id=#{partners}' scrolling = 'auto' width='513' height='600' frameborder='0' margin='0'></iframe><?php $userid = "+current_user.id.to_s+"; ?><br><?php $toemail = '"+current_user.email.to_s+"'; ?><br><?php include_once('tools/contactus.php'); ?></div>"
              when 'c21aboutus.html'
                p.content = "<div id='textcontent'><iframe src='http://c21wwcrest.idx.net/agents_profile.php?cid=#{current_user.company_id}&mode=agents&agent_id=#{partners}' scrolling = 'auto' width='513' height='600' frameborder='0' margin='0'></iframe></div>"
              when 'listings.html'
                p.title = 'All Listings'
              end
            end
            p.save
          end
        end
 
        flash[:subagent_notice]='Agent information saved sucessfully'
        redirect_to subagents_users_path
      else
        flash[:subagent_notice]='Invalid Agent Key! Agent Should be in same Office'
        redirect_to subagents_users_path
      end
    end
  end
 
  # DELETE /users/1
  # DELETE /users/1.xml
  def destroy
    @user.destroy
 
    respond_to do |format|
      format.html { redirect_to users_url }
      format.xml { head :ok }
    end
  end
 
  # ---------------------------------------------------------------------------
 
  def support
    #render support template
  end
 
  # POST method - used to send contact us mail to support team.
 
  EMAIL_REGEXP = %r{^[a-zA-Z][\w\.-]*[a-zA-Z0-9]?@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$}i
 
  def sendsupport
    @flag = 0
    @error=""
 
    if params[:support].blank? || params[:support][:email].blank? then @text, @flag, @error = "email", 1, "support_email"
    elsif params[:support][:email].to_s !~ EMAIL_REGEXP then @text, @flag, @error = "a valid email", 1, "support_email"
    elsif params[:support][:subject].blank? then @text, @flag, @error = "subject", 1, "support_subject"
    elsif params[:support][:problem].blank? then @text, @flag, @error = "Suggestions", 1, "support_problem"
    end
 
    if @flag == 1
      flash[:notice] = "Please enter the #{@text}"
      redirect_to support_users_path
    else
      Notification::deliver_mail_support(params[:support], current_user.name)
      redirect_to support_users_path(:support => :success)
    end
 
  end
 
  # ---------------------------------------------------------------------------
 
  include WebsitePublish
 
  # POST /users/id/activate
  def activate
    if do_publish_htaccess(@user, "normal")
      @user.update_attributes(:active => "Y")
      head :ok
    else
      head :not_found
    end
  end
 
  # POST /users/id/suspend
  def suspend
    if do_publish_htaccess(@user, "suspend")
      @user.update_attributes(:active => "N")
      head :ok
    else
      head :not_found
    end
  end
 
private
 
  def agent_info(sub)
    sub.delete('')
    partner_id = sub.push(current_user.agent_id)
    agent = C21Crest::Agent.find_by_sa_key(partner_id.compact.join(','))
    if agent.totlistings.to_i != sub.compact.size.to_i
      flash[:subagent_notice]= "Invalid Agent Key!"
      false
    else
      true
    end
  end
 
end
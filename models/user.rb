class User < ActiveRecord::Base
 
  track_changes_on :agent_id
 
  attr_accessor :action, :password_confirmation, :migrate_hashed_password, :migrate_salt
 
  has_many :attachments
  has_many :images
  has_many :individual_properties, :foreign_key => 'ip_user_id'
  has_many :listing_urls
  has_many :office_agents, :order => :position
  has_many :pages, :through => :websites
  has_many :slideshows, :foreign_key => 'userid'
  has_many :sub_agents, :order => 'sub_agent_id DESC'
  has_many :websites
 
  has_many :downloaded_whitepapers
  has_many :whitepapers, :through => :downloaded_whitepapers
 
  belongs_to :logo, :polymorphic => true
  belongs_to :partner
 
  EMAIL_REGEXP = %r{^(['_a-z0-9-]+)(\.['_a-z0-9-]+)*@([a-z0-9-]+)(\.[a-z0-9-]+)*(\.[a-z]{2,5})$}i
  FOLDER_REGEXP = %r{^([a-zA-Z0-9][\w\-]*[a-zA-Z0-9])+$}i
  NAME_REGEXP = %r{^([a-zA-Z0-9\.][\w\-]*[a-zA-Z0-9\.])+$}i
 
  validates_confirmation_of :password
 
  validates_format_of :email, :with => EMAIL_REGEXP, :message => "Must be a valid e-mail address."
  validates_format_of :folder, :with => FOLDER_REGEXP, :message => "Invalid name or no special characters."
  validates_format_of :name, :with => NAME_REGEXP, :message => "Invalid name or no special characters."
  validates_length_of :name, :within => 3..60, :message => "Name should be between 3 to 20 characters."
  validates_length_of :fax, :maximum => 20, :allow_nil => true
  validates_length_of :off_name, :maximum => 50
 
  validates_presence_of :address, :message => "can't be blank"
  validates_presence_of :agent_id, :message => "can't be blank"
  validates_presence_of :company_id, :message => "can't be blank"
  validates_presence_of :fname, :message => "can't be blank"
  validates_presence_of :folder, :message => "can't be blank"
  validates_presence_of :ftp_username, :message => "can't be blank"
  validates_presence_of :lname, :message => "can't be blank"
  validates_presence_of :name, :message => "can't be blank"
  validates_presence_of :off_name, :message => "can't be blank"
  validates_presence_of :password, :message => "can't be blank", :if => Proc.new {|m| m.action.to_s != "edit" && m.password.to_s != "" }
  validates_presence_of :password_confirmation, :message => "can't be blank", :if => Proc.new {|m| m.action.to_s != "edit" && m.password.to_s != "" }
  validates_presence_of :phone, :message => "can't be blank"
 
  validates_uniqueness_of :name
 
  include PHPHelper::InstanceMethods
 
  class << self
    def create_for_site(options)
      user = User.new options.only(:email, :fname, :lname, :password, :phone, :plan) # plan does not fit here.
      # now on Orderform there is a plan for each website of each user
 
      user.name = options[:domain_name] # this should change soon. User name should be independent of domain name
      user.ftp_username = options[:domain_name] # waste of DB? :)
      user.password_confirmation = user.password
      user.partner = Partner.find_by_name(options[:partner_name])
 
      address = %w|address address2 city state zip|.inject([]) { |res, key| res << options[key.intern]; res }.join(', ')
 
      password = EzCrypto::Key.with_password("webbuilderftp", "").encrypt(options[:password])
 
      user.address = address
      user.fax = String.new # waste of DB? :)
      user.folder = 'public_html'
      user.ftp_password = password
 
      # TODO probably the clean way of handling this will happen when we get rid of UserDetail
      # user_details = if options[:external_key] =~ /^21ONLINE/
      # UserDetails.create_for_site(options.dup.merge(:external_key => "99920036"))
      # else
      # UserDetails.create_for_site(options)
      # end
 
      user_details = UserDetails.create_for_site(options)
              
      user.agent_id = user_details.sakey
      user.company_id = user_details.company_id
      user.off_name = user_details.office_name
      user.office_id = user_details.office_id
      user.office_key = user_details.office_key
 
      # TODO I got the 'defaults' from the values on international users on production. Is this ok?
      user.company_id = "11111" if user.company_id.blank?
      user.off_name = "Century 21" if user.off_name.blank?
 
      user.save!
      user
    end
 
    def encrypted_password(password, salt)
      string_to_hash = password + "wibble" + salt
      Digest::SHA1.hexdigest(string_to_hash)
    end
 
    def check_admin(usr, pwd)
      (usr == 'admin' && pwd == 'spire+broad') ? usr : nil
    end
 
    def login(name, password)
      # TODO: search the USER by name, not the website.
      # the one website <-> one user relation must come to an end!
      website = Website.find_by_domain_name(name)
      user = website ? website.user : nil
      user && user.hashed_password == encrypted_password(password, user.salt) ? user : nil
    end
 
    def rand_word(*args)
      options = args.last.is_a?(Hash)? args.pop : {}
      options[:size] = 8 unless options[:size]
      options[:chars] = ("a".."z").to_a + ("A".."Z").to_a + (0..9).to_a unless options[:chars]
      chars = options[:chars].to_a
      size = options[:size].to_i
 
      (0...size).map {|n| chars[rand(chars.size)]}.join
    end
 
  end # class << self
 
  # ---------------------------------------------------------------------------
 
  def logo_attachments
    attachments.find :all, :conditions => { :purpose => "logo" }
  end
 
  def user_detail
    UserDetails.find_by_domainname(self.name)
  end
 
  def role
    Role.new(orderform_user.role)
  end
 
  def orderform_user
    Orderform::User.find_by_partner_and_user_name("century21", name)
  end
 
  def web_site
    Website.find_by_domain_name(self.name)
  end
 
  def subagents
    # subagent.to_s == subagent.id.to_s
    [self.agent_id, *sub_agents].map(&:to_s).delete_if(&:blank?).compact.join(',')
  end
 
  def international?
    self.agent_id == '99920036' || self.agent_id.to_s.upcase =~ /^21ONLINE/
  end
 
  def show_crest?
    not self.international?
  end
 
  def update_all_dependents(attrs)
    return false unless update_attributes(attrs[:user])
    update_from_c21crest
    self[:office_id] = attrs[:user][:office_id]
    save!
    update_offices_content
  end
 
  TABLE_FOR_AGENTS = <<-EOHTML
<div id='textcontent'>
<table border=0 width=530>
<tr>
<td valign=top>
<h1 style='color: #FDCD35; display: inline; font: normal normal bold large/normal "Tahoma";'>
Our Agents
</h1>
<br/>
<img src='/images/horizontal_line.gif' width='512' height='2' />
</td>
</tr>
<tr>
<td>
<%= iframe %>
</td>
<tr>
</table>
</div>
EOHTML
 
  def update_offices_content
    iframe = "<iframe src='http://c21wwcrest.idx.net/agents_list_broker.php?cid=#{self.company_id}&mode=office&office_id=#{self.office_id}' width='530' height='600' frameborder='0'></iframe>"
    content = ERB.new(TABLE_FOR_AGENTS).result(binding)
    our_agents = pages.find_by_url('ouragents.html')
    our_agents.update_attributes("content" => content) if our_agents
  end
 
  def update_from_c21crest(prebuilt = {})
    agent = prebuilt[:agent] || C21Crest::Agent.find_by_sa_key(agent_id)
    office = prebuilt[:office] || agent.office
 
    self[:company_id] = agent.company_id
    self[:office_id] = agent.office_id
    self[:off_name] = agent.office_name
    self[:office_key] = office.office_key
 
    save
    user_detail.update_from_c21crest(:office => office, :agent => agent) unless prebuilt.has_key?(:office) || prebuilt.has_key?(:agent)
 
  rescue C21Crest::RecordNotFound
    self.agent_id = nil
  end
 
  DISPLAY_AGENTS_HTML = <<-EOHTML
<br/>
<div id='textcontent'>
<table border=0 width=550>
<tr>
<td valign=top>
<h1 style='color: #FDCD35; display: inline; font: normal normal bold large/normal "Tahoma";'>
Our Agents
</h1>
<br/>
<img src='/images/horizontal_line.gif' width='512' height='2' />
</td>
</tr>
<tr>
<td>
<%= office_agents.map(&:agent_div).join %>
</td>
</tr>
</table>
</div>
EOHTML
 
  def display_agents
    ERB.new(DISPLAY_AGENTS_HTML).result(binding)
  end
 
  def decrypted_ftp_password
    EzCrypto::Key.with_password("webbuilderftp", "").decrypt(ftp_password) rescue ""
  end
 
  def password
    @password
  end
 
  def password=(pwd)
    @password = pwd
    create_new_salt
    self.hashed_password = User.encrypted_password(self.password, self.salt)
  end
 
  def safe_delete
    transaction do
      destroy
      raise "Can't delete last user" if User.count.zero?
    end
  end

  def padded_office_ids(zeroes = 4)
    (office_id || "").split(',').map { |number| sprintf("%0#{ zeroes }d", number.to_i) }
  end
 
  def main_site
    websites.detect { |w| not w.ips? }
  end
 
  def ip_sites
    websites - [main_site]
  end
 
  def granted_add_ons_count
    orderform_user.granted_add_ons_count
  end
 
  def percentage_for_meter
    whitepaper_percent = (whitepapers.length >= 2 ? 2 : whitepapers.length) * Configuration.whitepaper_points
    percent_main_site = publish != "Y" ? 0 : 15
    percent_ipsites = ip_sites.empty? ? 0 : 15
 
    total_percent = whitepaper_percent + percent_main_site + percent_ipsites + granted_add_ons_count * 10
 
    total_percent > 100 ? 100 : total_percent
  end
 
  def create_new_salt
    self.salt = object_id.to_s + rand.to_s
  end
 
  def full_name
    [fname, lname].reject(&:blank?).join(" ")
  end
 
  def footer_for_website
    "&copy; 2009 #{ "#{ full_name }, " if !role.broker? }CENTURY 21 #{ off_name }. #{ POSTFIX_FOOTER_FOR_WEBSITE }"
  end
 
  def title_for_website
    " #{ "| #{ full_name } " if !role.broker? }| CENTURY 21 #{ off_name }"
  end
 
  POSTFIX_FOOTER_FOR_WEBSITE = "All rights reserved. All content contained herein cannot be copied or used off this Web site in any way without the express written consent of the owner."
 
  def destroy
    paths = Set.new
 
    self.class.transaction do
      user_detail.destroy
 
      websites.each do |w|
        paths << File.join("public", "images", "websites", w.upload_folder)
        paths << File.join("public", "websites", w.domain_name)
        w.destroy
      end
 
      super
    end
 
    paths.each { |p| FileUtils.rm_rf p }
  end
 
end
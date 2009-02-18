require File.dirname(__FILE__) + '/../spec_helper'
Radiant::Config['reader.layout'] = 'Main'

describe PostsController do
  dataset :layouts
  dataset :forums
  dataset :topics
  dataset :forum_readers
  dataset :forum_pages
  
  before do
    @forum = Forum.create(:name => "test forum")
    @topic = @forum.topics.build(:name => "test topic")
    @topic.reader = readers(:normal)
    @topic.save!
    @post = @topic.posts.build(:body => "test post body")
    @post.reader = readers(:normal)
    @post.save!
  end

  describe "on get to index" do
    before do
      get :index
    end

    it "should render the list of posts by date" do
      response.should be_success
      response.should render_template("index")
    end  
  end
    
  describe "on get to show" do
    
    describe "for a page comment" do
      before do
        @page = pages(:commentable)
        @topic.page = @page
        @topic.save!
        get :show, :id => @post.id, :topic_id => @topic.id
      end
      it "should redirect to the page address and post anchor" do
        response.should be_redirect
        response.should redirect_to(@topic.page.url + "#comment_#{@post.id}")
      end
    end
    
    describe "for a normal post" do
      before do
        get :show, :id => @post.id, :topic_id => @topic.id
      end
      it "should redirect to the topic address and post anchor" do
        response.should be_redirect
        response.should redirect_to(topic_url(@topic.forum, @topic, {:page => @post.page, :anchor => "post_#{@post.id}"}))
      end
    end
            
    if defined? MultiSiteExtension
      describe "for a post on another site" do
        it "should return a file not found error" do
          
        end
      end
    end
  end
  
  describe "on get to new" do
    describe "without a logged-in reader" do
      before do
        logout_reader
      end

      describe "over normal http" do
        before do
          get :new, :topic_id => @topic.id
        end
        
        it "should redirect to login" do
          response.should be_redirect
          response.should redirect_to(reader_login_url)
        end
        
        it "should store the request address in the session" do
          request.session[:return_to].should == request.request_uri
        end
      end
      
      describe "by xmlhttprequest" do
        before do
          xhr :get, :new, :topic_id => @topic.id
        end

        it "should render a bare login form for inclusion in the page" do
          response.should be_success
          response.should render_template('readers/login')
          response.layout.should be_nil
        end
      end
      
    end

    describe "with a logged-in reader" do
      before do
        login_as_reader(:normal)
      end

      describe "but without proper context" do
        it "should throw a file not found error" do 
          lambda { get :new }.should raise_error(ActiveRecord::RecordNotFound)
          lambda { get :new, :topic_id => 'fish' }.should raise_error(ActiveRecord::RecordNotFound)
        end
      end

      describe "but to a locked topic" do
        before do
          @topic.locked = true
          @topic.save!
          get :new, :topic_id => @topic.id
        end
        
        it "should redirect to the topic page" do 
          response.should be_redirect
          response.should redirect_to(topic_url(@topic.forum, @topic))
        end
        
        it "should flash an appropriate message" do 
          flash[:notice].should_not be_nil
          flash[:notice].should =~ /locked/
        end
      end

      describe "over normal http" do
        before do
          get :new, :topic_id => @topic.id
        end

        it "should render the new post form in the normal way" do
          response.should be_success
          response.should render_template("new")
          response.layout.should == 'layouts/radiant'
        end
      end

      describe "by xmlhttprequest" do
        before do
          xhr :get, :new, :topic_id => @topic.id
        end

        it "should render a bare comment form for inclusion in the page" do
          response.should be_success
          response.should render_template('new')
          response.layout.should be_nil
        end
      end
    end
  end

  describe "on post to create" do
    describe "without a logged-in reader" do
      before do
        logout_reader
        post :create, :post => {:body => 'otherwise complete'}, :topic_id => @topic.id
      end
      
      it "should redirect to login" do
        response.should be_redirect
        response.should redirect_to(reader_login_url)
      end
    end

    describe "with a logged-in reader" do
      before do
        login_as_reader(:normal)
      end

      describe "but without proper context" do
        it "should throw a file not found error" do 
          lambda { post :create, :post => {:body => 'lacks topic context'} }.should raise_error(ActiveRecord::RecordNotFound)
        end
      end

      describe "but to a locked topic" do
        before do
          @topic.locked = true
          @topic.save!
        end
        
        describe "over normal http" do
          before do 
            post :create, :post => {:body => ''}, :topic_id => @topic.id
          end
          it "should redirect to the topic page" do 
            response.should be_redirect
            response.should redirect_to(topic_url(@topic.forum, @topic))
          end
          
          it "should flash an appropriate error" do 
            flash[:notice].should_not be_nil
            flash[:notice].should =~ /locked/
          end
        end
        describe "by xmlhttprequest" do
          before do
            xhr :post, :create, :post => {:body => 'otherwise complete'}, :topic_id => @topic.id
          end

          it "should render a bare 'locked' template for inclusion in the page" do
            response.should be_success
            response.should render_template('locked')
            response.layout.should be_nil
          end
        end
      end

      describe "but without a message body" do
        describe "over normal http" do
          before do 
            post :create, :post => {:body => ''}, :topic_id => @topic.id
          end
          
          it "should re-render the post form with layout" do
            response.should be_success
            response.should render_template('new')
            response.layout.should == 'layouts/radiant'
          end
        end
        
        describe "over xmlhttp" do
          before do
            xhr :post, :create, :post => {:body => ''}, :topic_id => @topic.id
          end

          it "should re-render the bare post form" do
            response.should be_success
            response.should render_template('new')
            response.layout.should be_nil
          end
        end
      end
    end
    
    describe "with a valid request" do
      before do
        login_as_reader(:normal)
      end

      it "should create the post" do
        post :create, :post => {:body => 'test post body'}, :topic_id => @topic.id
        @topic.reload
        @topic.posts.last.body.should == 'test post body'
      end
      
      describe "over xmlhttp" do
        before do
          xhr :post, :create, :post => {:body => 'test post body'}, :topic_id => @topic.id
        end
        it "should return the formatted message for inclusion in the page" do
          response.should be_success
          response.should render_template('show')
          response.layout.should be_nil
        end
      end

      describe "over normal http" do
        before do
          alphabet = ("a".."z").to_a
          body = Array.new(64, '').collect{alphabet[rand(alphabet.size)]}.join
          post :create, :post => {:body => body}, :topic_id => @topic.id
          @post = Post.find_by_body(body)
        end

        it "should redirect to the right topic and page" do
          response.should be_redirect
          response.should redirect_to(topic_url(@forum, @topic, {:page => @post.page, :anchor => "post_#{@post.id}"}))
        end
      end
    end

    describe "to attach a comment to a page" do
      it "should uncache the page" do

      end
    end

    if defined? MultiSiteExtension
      describe "when using multisite" do
        it "should not allow the creation of a post on another site" do
        
        end
      end
    end
  end
end

require File.absolute_path File.dirname(__FILE__) + '/../../test_helper'

describe HerokuVector::Engine::Heroku do
  let(:heroku_app_name) { 'app_name' }
  let(:mock_heroku) { mock('heroku_api') }
  let(:engine) { HerokuVector::Engine::Heroku.new(app: heroku_app_name, heroku: mock_heroku ) }
  let(:get_ps_response) { [ { "elapsed"=>21366, "process"=>"web.1" }, { "elapsed"=>83813, "process"=>"web.2" }, { "elapsed"=>1234, "process"=>"web.3" }, { "elapsed"=>83813, "process"=>"worker.1" } ] }

  describe '#initialize' do
    it 'should set app name from config' do
      assert_equal heroku_app_name, engine.app
    end

    it 'should instantiate a Heroku API client' do
      assert engine.heroku
    end
  end

  describe '#count_for_dyno_name' do
    it 'looks up dyno count' do
      engine.expects(:run_heroku_api_command).with(:get_ps, heroku_app_name).returns(get_ps_response)

      assert_equal 0, engine.count_for_dyno_name('unknown'), 'should return 0 for unknown dyno'
      assert_equal 3, engine.count_for_dyno_name('web'), 'should return dyno quantity from dynos set'
    end

    it 'caches the dyno information for 60 seconds' do
      engine.expects(:run_heroku_api_command).with(:get_ps, heroku_app_name).returns(get_ps_response).twice

      time = Time.now
      Timecop.freeze(time) do
        assert_equal 3, engine.count_for_dyno_name('web')
      end
      Timecop.freeze(time+30) do
        assert_equal 3, engine.count_for_dyno_name('web')
      end
      Timecop.freeze(time+61) do
        assert_equal 3, engine.count_for_dyno_name('web')
      end
    end
  end

  describe '#scale_dynos' do
    before do
      engine.expects(:run_heroku_api_command).with(:get_ps, heroku_app_name).returns(get_ps_response)
    end

    it 'does scale up if the count is larger than the current dyno number' do
      engine.expects(:run_heroku_api_command).with(:post_ps_scale, heroku_app_name, 'web', 4)
      engine.scale_dynos('web', 4)
    end

    it 'scales down oldest dyno first when downscaling' do
      engine.expects(:run_heroku_api_command).with(:post_ps_stop, heroku_app_name, { 'ps' => 'web.2' })
      engine.expects(:run_heroku_api_command).with(:post_ps_stop, heroku_app_name, { 'ps' => 'web.1' })
      engine.scale_dynos('web', 1)
    end
  end
end

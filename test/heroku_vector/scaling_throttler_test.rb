require File.absolute_path File.dirname(__FILE__) + '/../test_helper'

describe HerokuVector::ScalingThrottler do
  let(:throttler) do
    HerokuVector::ScalingThrottler.new
  end

  describe '#touch' do
    it 'sets last_scale_time to the current time' do
      time = Time.now
      Time.stubs(:now => time)
      throttler.touch
      assert_equal throttler.last_scale_time, time
    end
  end

  describe '#reset' do
    it 'sets last_scale_time to nil' do
      throttler.touch
      refute_nil throttler.last_scale_time
      throttler.reset
      assert_nil throttler.last_scale_time
    end
  end

  describe '#too_soon?' do
    it 'should not be too soon w/out last_scale_time' do
      assert_equal nil, throttler.last_scale_time
      assert_equal false, throttler.too_soon?
    end

    it 'should be too soon near last_scale_time' do
      throttler.last_scale_time = Time.now

      assert_equal true, throttler.too_soon?
    end

    it 'should not be too soon after last_scale_time' do
      threshold = HerokuVector::ScalingThrottler::MIN_SCALE_TIME_DELTA_SEC
      throttler.last_scale_time = Time.now - threshold - 1

      assert_equal false, throttler.too_soon?
    end
  end


end

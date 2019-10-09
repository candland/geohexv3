require "minitest/autorun"
require "json"
require "pp"

require_relative "../lib/geohex.rb"

describe "zone" do
  describe "tables" do
    tests = JSON.parse(File.read("test/tests.json"))

    tests.each do |test|
      it "#get_zone_by_code #{test[0]}" do
        code = test[0]
        lat = test[1]
        lon = test[2]

        zone = GeoHex.get_zone_by_code(code)

        zone.code.must_equal(code)
        zone.lat.must_be_within_epsilon(lat)
        zone.lon.must_be_within_epsilon(lon)
      end

      it "#get_zone_by_location #{test[0]}" do
        code = test[0]
        level = code.length - 2
        lat = test[1]
        lon = test[2]

        zone = GeoHex.get_zone_by_location(lat, lon, level)

        zone.code.must_equal(code)
        zone.lat.must_be_within_epsilon(lat)
        zone.lon.must_be_within_epsilon(lon)
      end
    end
  end

  describe "#loc_2_xy" do
    it "should retun x y" do
      s = GeoHex.loc_2_xy(-105, 39)

      s.x.must_equal(-11688546.531666666)
      s.y.must_equal(4721671.571922845)
    end
  end

  describe "#adjust_xy" do
    it "should adjust" do
      x = -11688546.531666666
      y = 4721671.571922845
      s = GeoHex.adjust_xy(x, y, 7)
      s.x.must_equal(-11668863.531666666)
      s.y.must_equal(4701988.571922846)

      s = GeoHex.adjust_xy(x, y, 4)
      s.x.must_equal(-11687817.531666666)
      s.y.must_equal(4720942.571922846)
    end
  end

  describe "#xy_2_loc" do
    it "should return lat lon" do
      s = GeoHex.xy_2_loc(1, 1)
      s.lon.must_equal(0.000008983152842445679)
      s.lat.must_equal(0.000008983152840993819)

      s = GeoHex.xy_2_loc(-11687817, 4720942)
      s.lon.must_equal(-104.99344650553493)
      s.lat.must_equal(38.99490651388566)

      s = GeoHex.xy_2_loc(-60, 366)
      s.lon.must_equal(-0.0005389891705467407)
      s.lat.must_equal(0.0032878339385315155)
    end
  end

  describe "#get_zone_by_xy" do
    it "should return zone" do
      z = GeoHex.get_zone_by_xy(-60, 366, 4)
      z.lat.must_be_within_epsilon(39.93141773898915)
      z.lon.must_be_within_epsilon(-105.18518518518519)
      z.code.must_equal("RU6064")
    end
  end

  describe "#get_zone_by_code" do
    it "should return zone" do
      z = GeoHex.get_zone_by_code("RU6064")
      z.lat.must_be_within_epsilon(39.93141773898915)
      z.lon.must_be_within_epsilon(-105.18518518518519)
      z.code.must_equal("RU6064")
    end
  end

  describe "#get_zone_by_location" do
    it "should return zone" do
      z = GeoHex.get_zone_by_location(39.931417738, -105.18518518, 4)

      z.code.must_equal("RU6064")
      z.x.must_be_within_epsilon(-60)
      z.y.must_be_within_epsilon(366)
    end
  end

  describe "cache_on" do
    before do
      GeoHex.cache_on = true
    end

    after do
      GeoHex.cache_on = false
    end

    it "should use memory cache" do
      GeoHex.cache_on.must_equal(true)

      z = GeoHex.get_zone_by_location(39.931417738, -105.18518518, 4)

      z.code.must_equal("RU6064")
      z.x.must_be_within_epsilon(-60)
      z.y.must_be_within_epsilon(366)
    end
  end
end

require "ostruct"

module GeoHex
  VERSION = "3.2.0"

  H_KEY = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  H_BASE = 20037508.34
  H_DEG = Math::PI * (30 / 180.0)
  H_K = Math.tan(H_DEG)

  @cache_on = false

  ZONE_CACHE = {}

  class Zone
    attr_accessor :code, :lat, :lon, :x, :y

    def initialize(lat, lon, x, y, code)
      @lat = lat
      @lon = lon
      @x = x
      @y = y
      @code = code
    end

    def level
      code.length - 2
    end

    def hex_size
      calcHexSize(level)
    end

    def hex_coods
      h_lat = lat
      h_lon = lon
      h_xy = GeoHex.loc_2_xy(h_lon, h_lat)
      h_x = h_xy.x
      h_y = h_xy.y
      h_deg = Math.tan(Math::PI * (60 / 180.0))
      h_size = hex_size

      h_top = xy_2_loc(h_x, h_y + h_deg *  h_size).lat
      h_btm = xy_2_loc(h_x, h_y - h_deg *  h_size).lat
      h_l = xy_2_loc(h_x - 2 * h_size, h_y).lon
      h_r = xy_2_loc(h_x + 2 * h_size, h_y).lon
      h_cl = xy_2_loc(h_x - 1 * h_size, h_y).lon
      h_cr = xy_2_loc(h_x + 1 * h_size, h_y).lon

      [
        {lat: h_lat, lon: h_l},
        {lat: h_top, lon: h_cl},
        {lat: h_top, lon: h_cr},
        {lat: h_lat, lon: h_r},
        {lat: h_btm, lon: h_cr},
        {lat: h_btm, lon: h_cl},
      ]
    end
  end

  def self.get_zone_by_location lat, lon, level
    xy = get_xy_by_location(lat, lon, level)
    get_zone_by_xy(xy.x, xy.y, level)
  end

  def self.get_zone_by_code code
    xy = get_xy_by_code(code)
    level = code.length - 2
    get_zone_by_xy(xy.x, xy.y, level)
  end

  def self.get_xy_by_location lat, lon, level
    h_size = calc_hex_size(level)
    z_xy = loc_2_xy(lon, lat)
    lon_grid = z_xy.x
    lat_grid = z_xy.y
    unit_x = 6 * h_size
    unit_y = 6 * h_size * H_K
    h_pos_x = (lon_grid + lat_grid / H_K) / unit_x
    h_pos_y = (lat_grid - H_K * lon_grid) / unit_y
    h_x_0 = h_pos_x.floor
    h_y_0 = h_pos_y.floor
    h_x_q = h_pos_x - h_x_0
    h_y_q = h_pos_y - h_y_0
    h_x = h_pos_x.round
    h_y = h_pos_y.round

    if h_y_q > -h_x_q + 1 # Negation ok?
      if (h_y_q < 2 * h_x_q) && (h_y_q > 0.5 * h_x_q)
        h_x = h_x_0 + 1
        h_y = h_y_0 + 1
      end
    elsif h_y_q < -h_x_q + 1 # Negation ok?
      if (h_y_q > (2 * h_x_q) - 1) && (h_y_q < (0.5 * h_x_q) + 0.5)
        h_x = h_x_0
        h_y = h_y_0
      end
    end

    inner_xy = adjust_xy(h_x, h_y, level)
    h_x = inner_xy.x
    h_y = inner_xy.y

    OpenStruct.new("x" => h_x, "y" => h_y)
  end

  def self.get_xy_by_code code
    level = code.length - 2
    # h_size = calcHexSize(level)
    # unit_x = 6 * h_size
    # unit_y = 6 * h_size * H_K
    h_x = 0
    h_y = 0
    h_dec9 = "#{H_KEY.index(code[0]) * 30 + H_KEY.index(code[1])}#{code[2..-1]}"

    if h_dec9[0].match(/[15]/) && h_dec9[1].match(/[^125]/) && h_dec9[2].match(/[^125]/)
      if h_dec9[0] == "5"
        h_dec9 = "7" + h_dec9[1..-1]
      elsif h_dec9[0] == "1"
        h_dec9 = "3" + h_dec9[1..-1]
      end
    end

    d9xlen = h_dec9.length

    (0...(level + 3 - d9xlen)).each do |i|
      # for (i = 0; i < level + 3 - d9xlen; i++) do
      h_dec9 = "0" + h_dec9
      d9xlen += 1
    end

    h_dec3 = ""
    (0...d9xlen).each do |i|
      # for (i = 0; i < d9xlen; i++) {
      h_dec0 = h_dec9[i].to_i.to_s(3)
      if !h_dec0
        h_dec3 += "00"
      elsif h_dec0.length == 1
        h_dec3 += "0"
      end
      h_dec3 += h_dec0
    end

    h_decx = []
    h_decy = []

    (0...(h_dec3.length / 2)).each do |i|
      # for (i = 0; i < h_dec3.length / 2; i++) {
      h_decx[i] = h_dec3[i * 2].to_i
      h_decy[i] = h_dec3[i * 2 + 1].to_i
    end

    (0..(level + 2)).each do |i|
      # for (i = 0; i <= level + 2; i++) {
      h_pow = 3**(level + 2 - i)

      if h_decx[i] == 0
        h_x -= h_pow
      elsif h_decx[i] == 2
        h_x += h_pow
      end
      if h_decy[i] == 0
        h_y -= h_pow
      elsif h_decy[i] == 2
        h_y += h_pow
      end
    end

    inner_xy = adjust_xy(h_x, h_y, level)
    h_x = inner_xy.x
    h_y = inner_xy.y

    OpenStruct.new("x" => h_x, "y" => h_y)
  end

  def self.get_zone_by_xy x, y, level
    h_size = calc_hex_size(level)

    h_x = x
    h_y = y

    unit_x = 6 * h_size
    unit_y = (6 * h_size) * H_K

    h_lat = (H_K * h_x * unit_x + h_y * unit_y) / 2
    h_lon = (h_lat - h_y * unit_y) / H_K

    z_loc = xy_2_loc(h_lon, h_lat)
    z_loc_x = z_loc.lon
    z_loc_y = z_loc.lat

    max_hsteps = 3**(level + 2)
    hsteps = (h_x - h_y).abs

    if hsteps == max_hsteps
      if h_x > h_y
        tmp = h_x
        h_x = h_y
        h_y = tmp
      end
      z_loc_x = -180
    end

    h_code = ""
    code3_x = []
    code3_y = []
    code3 = ""
    code9 = ""
    mod_x = h_x
    mod_y = h_y

    (0..(level + 2)).each do |i|
      # for (i = 0; i <= _level + 2; i++) {
      h_pow = 3**(level + 2 - i)
      half_h_pow = (h_pow / 2.0).ceil

      if mod_x >= half_h_pow
        code3_x[i] = 2
        mod_x -= h_pow
      elsif mod_x <= -half_h_pow
        code3_x[i] = 0
        mod_x += h_pow
      else
        code3_x[i] = 1
      end

      if mod_y >= half_h_pow
        code3_y[i] = 2
        mod_y -= h_pow
      elsif mod_y <= -half_h_pow
        code3_y[i] = 0
        mod_y += h_pow
      else
        code3_y[i] = 1
      end

      if i == 2 && (z_loc_x == -180 || z_loc_x >= 0)
        if code3_x[0] == 2 && code3_y[0] == 1 && code3_x[1] == code3_y[1] && code3_x[2] == code3_y[2]
          code3_x[0] = 1
          code3_y[0] = 2
        elsif code3_x[0] == 1 && code3_y[0] == 0 && code3_x[1] == code3_y[1] && code3_x[2] == code3_y[2]
          code3_x[0] = 0
          code3_y[0] = 1
        end
      end
    end

    (0...code3_x.length).each do |i|
      # for (i = 0; i < code3_x.length; i++) {
      code3 = "#{code3_x[i]}#{code3_y[i]}"
      code9 = code3.to_i(3).to_s
      h_code += code9
    end

    h_2 = h_code[3..-1]
    h_1 = h_code[0, 3].to_i
    h_a1 = (h_1 / 30).floor
    h_a2 = h_1 % 30
    h_code = "#{H_KEY[h_a1]}#{H_KEY[h_a2]}#{h_2}"

    if @cache_on
      return ZONE_CACHE[h_code] if ZONE_CACHE[h_code]
      return ZONE_CACHE[h_code] = Zone.new(z_loc_y, z_loc_x, x, y, h_code)
    else
      return Zone.new(z_loc_y, z_loc_x, x, y, h_code)
    end
  end

  def self.adjust_xy x, y, level
    x = x
    y = y
    rev = 0
    max_hsteps = 3**(level + 2)
    hsteps = (x - y).abs

    if hsteps == max_hsteps && x > y
      tmp = x
      x = y
      y = tmp
      rev = 1
    elsif hsteps > max_hsteps
      dif = hsteps - max_hsteps
      dif_x = (dif / 2).floor
      dif_y = dif - dif_x
      edge_x = nil
      edge_y = nil
      if x > y
        edge_x = x - dif_x
        edge_y = y + dif_y
        h_xy = edge_x
        edge_x = edge_y
        edge_y = h_xy
        x = edge_x + dif_x
        y = edge_y - dif_y
      elsif y > x
        edge_x = x + dif_x
        edge_y = y - dif_y
        h_xy = edge_x
        edge_x = edge_y
        edge_y = h_xy
        x = edge_x - dif_x
        y = edge_y + dif_y
      end
    end

    OpenStruct.new("x" => x, "y" => y, "rev" => rev)
  end

  def self.loc_2_xy(lon, lat)
    x = lon * H_BASE / 180
    y = Math.log(Math.tan((90 + lat) * Math::PI / 360.0)) / (Math::PI / 180.0)
    y = y * H_BASE / 180
    OpenStruct.new("x" => x, "y" => y)
  end

  def self.xy_2_loc(x, y)
    lon = (x / H_BASE) * 180
    lat = (y / H_BASE) * 180
    lat = 180.0 / Math::PI * (2.0 * Math.atan(Math.exp(lat * Math::PI / 180.0)) - Math::PI / 2.0)
    OpenStruct.new("lon" => lon, "lat" => lat)
  end

  def self.calc_hex_size(level)
    H_BASE / 3**(level + 3)
  end

  def self.cache_on
    @cache_on
  end

  def self.cache_on= value
    @cache_on = value
  end
end

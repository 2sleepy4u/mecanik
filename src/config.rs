pub struct Config {
    pub serial_path: String,
    pub baud_rate: u32
}

impl Default for Config {
    fn default() -> Self {
        Self {
            serial_path: "".to_string(),
            baud_rate: 9600
        }
    }
}

struct PressureGaugeConfig {
    divisions: i32,
    low_level_alarm: i32,
    high_level_alarm: i32,
}

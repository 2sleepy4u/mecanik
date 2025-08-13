use rand::Rng;
use serialport::SerialPort;

use crate::model::{Data, DataLogger};

pub struct DummyLogger(pub Data);

impl DataLogger for DummyLogger {
    fn read(&mut self) -> Result<Data, std::io::Error> {
        let mut rng = rand::rng();
        self.0.oil_pressure += rng.random_range(-3..7);
        self.0.fuel_pressure += rng.random_range(-7..10);
        self.0.turbo_pressure += rng.random_range(-5..10);

        self.0.oil_pressure = self.0.oil_pressure.max(0).min(100);
        self.0.fuel_pressure = self.0.fuel_pressure.max(0).min(100);
        self.0.turbo_pressure = self.0.turbo_pressure.max(0).min(100);

        Ok(self.0.clone())
    }
}

pub struct SerialLogger {
    serialport: Box<dyn SerialPort>
}

impl SerialLogger {
    pub fn new(serial_path: String, baud_rate: u32) -> Self {
        let serialport = serialport::new(serial_path, baud_rate)
        .open()
        .expect("Serial not connected");



        Self {
            serialport
        }
    }
}

impl DataLogger for SerialLogger {
    fn read(&mut self) -> Result<Data, std::io::Error> {
        let mut buf = Vec::new();
        self.serialport.read(&mut buf)?;
        // Ok(buf)
        Ok(Data::default())
    }
}

use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Default, Clone)]
pub struct Data {
    pub oil_pressure: i32,
    pub fuel_pressure: i32,
    pub turbo_pressure: i32,
}

#[derive(Debug, thiserror::Error)]
enum DataLoggerError {
    #[error("Serial port error: {0}")]
    SerialError(#[from] serialport::Error)
}

pub trait DataLogger {
    fn read(&mut self) -> Result<Data, std::io::Error>;
}






slint::include_modules!();
pub mod config;
pub mod model;
pub mod loggers;

use model::{Data, DataLogger};
use loggers::DummyLogger;
use slint::{ComponentHandle, Weak};

fn main() -> Result<(), slint::PlatformError> {
    let _config = config::Config::default();
    
    let main_window = MainWindow::new()?;

    let ui = main_window.as_weak();

        
    slint::spawn_local(async_compat::Compat::new(async_future(ui))).unwrap();
    main_window.run()
}


async fn async_future(ui: Weak<MainWindow>) {
    let mut dummy = DummyLogger(Data::default());
    let ui = ui.clone();
    while let Ok(data) = dummy.read() {
        let main_window = ui.unwrap();
        main_window.set_oil_pressure(data.oil_pressure);
        main_window.set_fuel_pressure(data.fuel_pressure);
        main_window.set_turbo_pressure(data.turbo_pressure);
        tokio::time::sleep(tokio::time::Duration::from_millis(200)).await;
    }
}

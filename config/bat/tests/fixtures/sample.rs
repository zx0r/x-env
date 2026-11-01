// Environment X Syntax Test Fixture: Rust
use std::collections::HashMap;

/// Master interface specification
pub trait KernelProcessor<'a, T: Clone> {
    fn process(&self, input: &'a str) -> Result<T, &'static str>;
}

#[derive(Debug, Clone)]
pub struct EngineConfig<'a> {
    pub name: &'a str,
    pub timeout_ms: u64,
    pub enabled: bool,
    pub weights: Vec<f64>,
}

impl<'a> EngineConfig<'a> {
    pub const DEFAULT_TIMEOUT: u64 = 5_000;

    pub fn new(name: &'a str) -> Self {
        Self {
            name,
            timeout_ms: Self::DEFAULT_TIMEOUT,
            enabled: true,
            weights: vec![0.15, 0.85],
        }
    }
}

pub async fn execute_pipeline<'a>(config: &EngineConfig<'a>) -> Option<HashMap<String, usize>> {
    println!("Initializing engine: {} with timeout {}ms", config.name, config.timeout_ms);
    let mut metrics = HashMap::new();
    match config.enabled {
        true => {
            metrics.insert("status_code".to_string(), 200);
            Some(metrics)
        }
        false => None,
    }
}

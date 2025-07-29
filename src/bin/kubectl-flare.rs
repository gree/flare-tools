use clap::{Arg, Command};
use std::process::{self, Stdio};

fn main() {
    let matches = Command::new("kubectl-flare")
        .version("1.0.0")
        .about("kubectl plugin for flare-tools")
        .long_about("kubectl-flare is a kubectl plugin that runs flare-tools commands on the index server. It automatically finds the flare index server pod and executes flare-admin or flare-stats commands.")
        .arg(Arg::new("namespace")
            .long("namespace")
            .short('n')
            .value_name("NAMESPACE")
            .help("Kubernetes namespace")
            .default_value("default"))
        .arg(Arg::new("pod-selector")
            .long("pod-selector")
            .value_name("SELECTOR")
            .help("Label selector to find index server pod")
            .default_value("statefulset.kubernetes.io/pod-name=index-0"))
        .arg(Arg::new("container")
            .long("container")
            .value_name("CONTAINER")
            .help("Container name in the pod")
            .default_value("flarei"))
        .subcommand(Command::new("admin")
            .about("Run flare-admin commands")
            .arg(Arg::new("args")
                .help("Arguments to pass to flare-admin")
                .action(clap::ArgAction::Append)
                .allow_hyphen_values(true)))
        .subcommand(Command::new("stats")
            .about("Run flare-stats commands")
            .arg(Arg::new("args")
                .help("Arguments to pass to flare-stats")
                .action(clap::ArgAction::Append)
                .allow_hyphen_values(true)))
        .arg(Arg::new("args")
            .help("Command and arguments")
            .action(clap::ArgAction::Append)
            .allow_hyphen_values(true))
        .get_matches();

    let namespace = matches.get_one::<String>("namespace").unwrap();
    let pod_selector = matches.get_one::<String>("pod-selector").unwrap();
    let container = matches.get_one::<String>("container").unwrap();

    // Find the index server pod
    let pod = match find_index_server_pod(namespace, pod_selector) {
        Ok(pod) => pod,
        Err(e) => {
            eprintln!("Error finding index server pod: {}", e);
            process::exit(1);
        }
    };

    // Determine which tool to run and build arguments
    let (tool, tool_args) = match matches.subcommand() {
        Some(("admin", sub_matches)) => {
            let args: Vec<String> = if let Some(arg_values) = sub_matches.get_many::<String>("args") {
                arg_values.cloned().collect()
            } else {
                Vec::new()
            };
            ("flare-admin", args)
        }
        Some(("stats", sub_matches)) => {
            let args: Vec<String> = if let Some(arg_values) = sub_matches.get_many::<String>("args") {
                arg_values.cloned().collect()
            } else {
                Vec::new()
            };
            ("flare-stats", args)
        }
        _ => {
            // Default behavior: use raw arguments
            let args: Vec<String> = if let Some(arg_values) = matches.get_many::<String>("args") {
                arg_values.cloned().collect()
            } else {
                eprintln!("No command specified. Use 'kubectl flare admin <args>' or 'kubectl flare stats <args>'");
                process::exit(1);
            };
            
            if args.is_empty() {
                eprintln!("No arguments provided");
                process::exit(1);
            }
            
            // First argument determines the tool
            match args[0].as_str() {
                "admin" => ("flare-admin", args[1..].to_vec()),
                "stats" => ("flare-stats", args[1..].to_vec()),
                _ => ("flare-admin", args), // Default to flare-admin for backward compatibility
            }
        }
    };

    // Build kubectl exec command
    let mut kubectl_args = vec![
        "exec".to_string(),
        "-n".to_string(), namespace.clone(),
        "-c".to_string(), container.clone(),
        pod,
        "--".to_string(),
        tool.to_string(),
    ];
    kubectl_args.extend(tool_args);

    // Execute kubectl exec
    let status = process::Command::new("kubectl")
        .args(&kubectl_args)
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status();

    match status {
        Ok(exit_status) => {
            if let Some(code) = exit_status.code() {
                process::exit(code);
            } else {
                process::exit(1);
            }
        }
        Err(e) => {
            eprintln!("Error executing kubectl command: {}", e);
            process::exit(1);
        }
    }
}

fn find_index_server_pod(namespace: &str, pod_selector: &str) -> Result<String, Box<dyn std::error::Error>> {
    // Get pods matching the selector
    let output = process::Command::new("kubectl")
        .args(&[
            "get", "pods",
            "-n", namespace,
            "-l", pod_selector,
            "-o", "name",
            "--no-headers"
        ])
        .output()?;

    if !output.status.success() {
        return Err(format!("kubectl command failed: {}", String::from_utf8_lossy(&output.stderr)).into());
    }

    let output_str = String::from_utf8(output.stdout)?;
    let pods: Vec<&str> = output_str.trim().split('\n').collect();
    
    if pods.is_empty() || pods[0].is_empty() {
        return Err(format!("No pods found with selector {}", pod_selector).into());
    }

    // Return the first pod name (remove "pod/" prefix if present)
    let pod_name = pods[0].strip_prefix("pod/").unwrap_or(pods[0]);
    Ok(pod_name.to_string())
}
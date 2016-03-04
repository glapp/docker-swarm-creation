# Docker Swarm Creation

Just throw your scripts into this repo. Don't include personal keys, though!

## If you need personal keys:
* Save these keys in a separate file (e.g. ``config/keys``)
* Put it into the ``.gitignore`` file (just by adding a new line with the directory/file)
* Save a generic sample-file (e.g. ``config/keysSample``), where you replace your personal keys with a placeholder
    * We can later save this file as ``config/keys``, making it gitignored automatically
* As your script file is generic and refers to this external file for personal keys, we all can use the same script file :-)


## demo_set_up_swar_cloud.sh
You need to have the file prometheus_template.yml in the folder: '/home/<user>/prometheus/prometheus-cloud/prometheus_template.yml'
otherwise the Prometheus server won't start.
You can use the demo_deleteVMs_in_cloud.sh

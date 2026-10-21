"""Compare the actual packaging job and its inherited execution settings."""
import json,subprocess,sys
from pathlib import Path
RUBY=r'''
require 'yaml'
require 'json'
workflows=JSON.parse(STDIN.read)
result=workflows.map do |source|
  document=YAML.safe_load(source)
  raise 'missing package job' unless document.is_a?(Hash) && document.fetch('jobs',{}).key?('package')
  environment=document.fetch('env',{}).dup
  reuse=environment.delete('SDK_REUSE_RUN')
  raise 'invalid reuse slot' unless reuse.is_a?(String) && reuse.match?(/\A[0-9]*\z/)
  [document['jobs']['package'],environment,document['defaults'],document['permissions']]
end
puts JSON.generate(result)
'''
def same_packaging(previous,current):
    p=subprocess.run(['ruby','-e',RUBY],input=json.dumps([previous,current]),text=True,capture_output=True)
    if p.returncode:return False
    first,second=json.loads(p.stdout)
    return first==second
if __name__=='__main__':
    if not same_packaging(Path(sys.argv[1]).read_text(),Path(sys.argv[2]).read_text()):
        raise SystemExit('Packaging job or inherited inputs changed; refusing reuse')

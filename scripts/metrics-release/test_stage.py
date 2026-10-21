import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from test_contract import acceptance,query
from contract import SOURCE

class RepositoryStage(unittest.TestCase):
    def test_original_payloads_and_identities_are_staged_without_overwrite(self):
        from stage import stage
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);candidate=root/'candidate';(candidate/'rpms').mkdir(parents=True)
            (candidate/'evidence').mkdir();(candidate/'test-evidence').mkdir();(candidate/'build-evidence').mkdir()
            digests={}
            for kind,arch in [('collector','x86_64'),('monitor','noarch')]:
                name=f'ambari-metrics-{kind}-3.0.0-1.oe2203sp4.{arch}.rpm'
                data=name.encode();(candidate/'rpms'/name).write_bytes(data)
                digests[name]=hashlib.sha256(data).hexdigest()
            (candidate/'evidence/SHA256SUMS').write_text(''.join(d+'  rpms/'+n+'\n' for n,d in digests.items()))
            inputs={'scripts/ambari-metrics/runtime.sh':'a'*64}
            identity=hashlib.sha256(json.dumps(inputs,sort_keys=True,separators=(',',':')).encode()).hexdigest()
            value={'schema':'bigdata.metrics-candidate/v1','component':'ambari-metrics','version':'3.0.0',
                   'source_identity':SOURCE,'compatibility_identity':identity,'packaging_inputs':inputs,
                   'build_run_id':123,'test_run_id':124,'producer_head':'b'*40,'tested_head':'c'*40,
                   'rpm_sha256':digests,'actual_acceptance':'PASS','publication':'NOT_RUN'}
            candidate_file=candidate/'evidence/candidate.json';candidate_file.write_text(json.dumps(value))
            evidence=candidate/'test-evidence'
            (evidence/'acceptance.json').write_text(json.dumps(acceptance()))
            (evidence/'initial-query.json').write_text(json.dumps(query({'cpu_user':{'100000':1},'mem_total':{'100000':8192}},110000)))
            (evidence/'restarted-query.json').write_text(json.dumps(query({'cpu_user':{'100000':1,'120000':2},'mem_total':{'100000':8192,'120000':8192}},130000)))
            (evidence/'collector.log').write_text('upstream runtime diagnostic   \n')
            with patch.dict(os.environ,{'GITHUB_SHA':'d'*40}):
                target=root/'repo';stage(candidate,target)
                self.assertEqual(set(p.name for p in target.glob('*.rpm')),set(digests))
                self.assertFalse((target/'test-evidence/collector.log').exists())
                index=json.loads((target/'test-evidence/artifact-index.json').read_text())
                self.assertEqual(index['files']['collector.log'],hashlib.sha256(b'upstream runtime diagnostic   \n').hexdigest())
                self.assertEqual(index['test_run_id'],124)
                manifest=(target/'manifest.yaml').read_text()
                self.assertIn('build_run_id: 123',manifest);self.assertIn('test_run_id: 124',manifest)
                with self.assertRaises(ValueError):stage(candidate,target)
                changed=copy.deepcopy(value);changed['actual_acceptance']='SKIPPED';candidate_file.write_text(json.dumps(changed))
                with self.assertRaises(ValueError):stage(candidate,root/'invalid')
                self.assertFalse((root/'invalid').exists())

    def test_metadata_must_index_exact_original_runtime_bytes(self):
        import gzip
        from stage import verify_metadata
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);(root/'repodata').mkdir()
            checksums=[];entries=[]
            for kind,arch in [('collector','x86_64'),('monitor','noarch')]:
                name=f'ambari-metrics-{kind}-3.0.0-1.oe2203sp4.{arch}.rpm'
                data=name.encode();(root/name).write_bytes(data)
                digest=hashlib.sha256(data).hexdigest();checksums.append(digest+'  ./'+name+'\n')
                entries.append(f'<package type="rpm"><name>ambari-metrics-{kind}</name><arch>{arch}</arch><version ver="3.0.0" rel="1.oe2203sp4"/><checksum type="sha256">{digest}</checksum><location href="{name}"/></package>')
            (root/'SHA256SUMS').write_text(''.join(checksums))
            primary=gzip.compress(('<metadata packages="2">'+''.join(entries)+'</metadata>').encode())
            (root/'repodata/primary.xml.gz').write_bytes(primary)
            digest=hashlib.sha256(primary).hexdigest()
            (root/'repodata/repomd.xml').write_text(f'<repomd><data type="primary"><checksum type="sha256">{digest}</checksum><location href="repodata/primary.xml.gz"/></data></repomd>')
            verify_metadata(root)
            (root/'repodata/primary.xml.gz').write_bytes(b'changed')
            with self.assertRaises(Exception):verify_metadata(root)

if __name__=='__main__':unittest.main()

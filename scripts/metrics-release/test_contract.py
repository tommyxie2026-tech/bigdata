import copy
import unittest
from contract import validate_acceptance,validate_queries,validate_checksums


def acceptance():
    return {'component':'ambari-metrics','version':'3.0.0',
        'source_identity':'ce919386e963841ea37f032c5ba6ed9c48298dd8',
        **{k:'PASS' for k in ['clean_openEuler_rpm_install','actual_host_collection',
            'collector_timestamp_query','restart_historical_values','fresh_metrics_after_restart']},
        'service_processes':[{'hbase':1,'collector':2,'monitor':3},{'hbase':4,'collector':5,'monitor':6}]}


def query(points,at=200000):
    return {'hostname':'host','queried_at_ms':at,
        'accepted_samples':points,
        'query':{'metrics':[{'hostname':'host','appid':'HOST','metricname':name,'metrics':copy.deepcopy(values)}
            for name,values in points.items()]}}


class PublicationContract(unittest.TestCase):
    def test_all_actual_acceptance_gates_and_new_processes_are_required(self):
        value=acceptance();validate_acceptance(value)
        for key in ['clean_openEuler_rpm_install','actual_host_collection','collector_timestamp_query',
                    'restart_historical_values','fresh_metrics_after_restart']:
            for bad in ['NOT_RUN','SKIPPED',None]:
                broken=copy.deepcopy(value);broken[key]=bad
                with self.subTest(key=key,bad=bad),self.assertRaises(ValueError):validate_acceptance(broken)
        for mutation in ['same_pid','wrong_source','missing_service','boolean_pid']:
            broken=copy.deepcopy(value)
            if mutation=='same_pid':broken['service_processes'][1]['collector']=2
            if mutation=='wrong_source':broken['source_identity']='a'*40
            if mutation=='missing_service':del broken['service_processes'][1]['monitor']
            if mutation=='boolean_pid':broken['service_processes'][1]['monitor']=True
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):validate_acceptance(broken)

    def test_real_samples_history_and_fresh_post_restart_values_are_required(self):
        before=query({'cpu_user':{'100000':12},'mem_total':{'100000':8192}},at=110000)
        after=query({'cpu_user':{'100000':12,'120000':14},'mem_total':{'100000':8192,'120000':8192}},at=130000)
        validate_queries(before,after)
        for mutation in ['lost_history','changed_history','no_fresh','wrong_host','nan','future','fake_accepted']:
            broken=copy.deepcopy(after)
            if mutation=='lost_history':del broken['accepted_samples']['cpu_user']['100000']
            if mutation=='changed_history':broken['accepted_samples']['cpu_user']['100000']=13
            if mutation=='no_fresh':broken=copy.deepcopy(before)
            if mutation=='wrong_host':broken['hostname']='other'
            if mutation=='nan':broken['accepted_samples']['cpu_user']['120000']=float('nan')
            if mutation=='future':broken['queried_at_ms']=100000
            if mutation=='fake_accepted':broken['query']['metrics'][0]['metrics']['120000']=55
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):validate_queries(before,broken)

    def test_exact_payload_digests_and_no_extra_or_symlink_packages(self):
        import hashlib,tempfile
        from pathlib import Path
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);(root/'rpms').mkdir();(root/'evidence').mkdir()
            names=['ambari-metrics-collector-3.0.0-1.oe2203sp4.x86_64.rpm',
                   'ambari-metrics-monitor-3.0.0-1.oe2203sp4.noarch.rpm']
            index=[]
            for name in names:
                value=name.encode();(root/'rpms'/name).write_bytes(value)
                index.append(hashlib.sha256(value).hexdigest()+'  ./'+name)
            (root/'evidence/SHA256SUMS').write_text('\n'.join(index)+'\n')
            self.assertEqual(set(validate_checksums(root)),set(names))
            (root/'rpms'/names[0]).write_text('changed')
            with self.assertRaises(ValueError):validate_checksums(root)
            (root/'rpms'/names[0]).write_bytes(names[0].encode())
            (root/'rpms/extra.rpm').write_text('extra')
            with self.assertRaises(ValueError):validate_checksums(root)
            (root/'rpms/extra.rpm').unlink()
            original=root/'rpms'/names[0];original.unlink();original.symlink_to(root/'evidence/SHA256SUMS')
            with self.assertRaises(ValueError):validate_checksums(root)

if __name__=='__main__':unittest.main()

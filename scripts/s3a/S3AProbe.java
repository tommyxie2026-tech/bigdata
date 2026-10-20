import java.io.*;
import java.net.URI;
import java.security.MessageDigest;
import java.util.*;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.*;

/** Real Hadoop S3A calls; no mock filesystem or locally substituted JARs. */
public final class S3AProbe {
  static final String ROOT="s3a://bigdata-ci-fixture/s3a/";
  static final byte[] SMALL="hadoop-3.4.3-s3a-persistent-proof".getBytes(java.nio.charset.StandardCharsets.UTF_8);
  static String phase;
  static void require(boolean ok,String message){if(!ok)throw new AssertionError(message);}
  static void pass(String check){System.out.println("S3A_PASS "+phase+" "+check);}
  static Configuration config(boolean reader){
    Configuration c=new Configuration(false);
    c.set("fs.s3a.impl","org.apache.hadoop.fs.s3a.S3AFileSystem");
    c.set("fs.s3a.endpoint","https://localhost:8334");
    c.set("fs.s3a.endpoint.region","us-east-1");
    c.setBoolean("fs.s3a.path.style.access",true);
    c.setBoolean("fs.s3a.connection.ssl.enabled",true);
    c.set("fs.s3a.aws.credentials.provider","org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider");
    c.set("fs.s3a.access.key",reader?"fixture-reader":"fixture-admin");
    c.set("fs.s3a.secret.key",reader?"fixture-reader-secret":"fixture-admin-secret");
    c.set("fs.s3a.connection.establish.timeout","5s");
    c.set("fs.s3a.connection.timeout","10s");
    c.setInt("fs.s3a.retry.limit",1);
    c.setInt("fs.s3a.attempts.maximum",2);
    c.setLong("fs.s3a.multipart.size",5*1024*1024);
    c.setLong("fs.s3a.multipart.threshold",5*1024*1024);
    c.setBoolean("fs.s3a.fast.upload",true);
    c.set("fs.s3a.fast.upload.buffer","array");
    return c;
  }
  static FileSystem fs(boolean reader)throws Exception{return FileSystem.newInstance(new URI(ROOT),config(reader));}
  static byte[] payload(){byte[] p=new byte[12*1024*1024];for(int i=0;i<p.length;i++)p[i]=(byte)((i*31+17)%251);return p;}
  static void put(FileSystem f,String key,byte[] p)throws Exception{try(FSDataOutputStream o=f.create(new Path(ROOT+key),false)){o.write(p);}}
  static void exact(FileSystem f,String key,byte[] p)throws Exception{
    byte[] actual=new byte[p.length];
    try(FSDataInputStream in=f.open(new Path(ROOT+key))){in.readFully(actual);require(in.read()==-1,"extra bytes");}
    require(Arrays.equals(actual,p),"content differs: "+key);
    StringBuilder hex=new StringBuilder();for(byte b:MessageDigest.getInstance("SHA-256").digest(actual))hex.append(String.format("%02x",b&255));
    System.out.println("SHA256 "+key+" "+hex);
  }
  interface Operation{void run()throws Exception;}
  static void denied(Operation operation)throws Exception{
    try{operation.run();}catch(IOException e){
      for(Throwable t=e;t!=null;t=t.getCause()){
        try{if(Integer.valueOf(403).equals(t.getClass().getMethod("statusCode").invoke(t)))return;}
        catch(ReflectiveOperationException ignored){}
      }
      throw new AssertionError("Failure was not an actual HTTP 403",e);
    }
    throw new AssertionError("Unauthorized operation succeeded");
  }
  static void inventory(FileSystem f,Set<String> expected)throws Exception{
    Set<String> keys=new HashSet<>();RemoteIterator<LocatedFileStatus> it=f.listFiles(new Path(ROOT),true);
    String prefix=new URI(ROOT).getPath();
    while(it.hasNext()){String path=it.next().getPath().toUri().getPath();require(path.startsWith(prefix),"outside prefix");String key=path.substring(prefix.length());require(keys.add(key),"duplicate key");}
    require(keys.equals(expected),"unexpected inventory: "+keys);
  }
  public static void main(String[] args)throws Exception{
    phase=args[0];require(phase.equals("initial")||phase.equals("restored"),"invalid phase");
    try(FileSystem f=fs(false)){
      require(f.getClass().getName().equals("org.apache.hadoop.fs.s3a.S3AFileSystem"),"wrong filesystem");
      if(phase.equals("initial")){
        put(f,"small.bin",SMALL);exact(f,"small.bin",SMALL);pass("tls_verified");
        put(f,"multipart.bin",payload());exact(f,"multipart.bin",payload());
        require(f.rename(new Path(ROOT+"small.bin"),new Path(ROOT+"proof.bin")),"rename failed");
        require(!f.exists(new Path(ROOT+"small.bin")),"rename retained source");
        exact(f,"proof.bin",SMALL);pass("crud_exact");
        inventory(f,new HashSet<>(Arrays.asList("proof.bin","multipart.bin")));pass("list_exact");
        try(FSDataInputStream in=f.open(new Path(ROOT+"multipart.bin"))){in.seek(6*1024*1024+17);require(in.read()==(payload()[6*1024*1024+17]&255),"seek mismatch");}pass("seek");
        try(FileSystem r=fs(true)){exact(r,"proof.bin",SMALL);pass("readonly");denied(()->put(r,"forbidden.bin",SMALL));pass("denied_write");}
        pass("retained");
      }else{
        // API probe readiness is checked separately before this fresh JVM starts.
        exact(f,"proof.bin",SMALL);exact(f,"multipart.bin",payload());pass("restart_exact");
        try(FileSystem r=fs(true)){exact(r,"proof.bin",SMALL);pass("readonly");denied(()->r.delete(new Path(ROOT+"proof.bin"),false));pass("denied_delete");}
        require(f.delete(new Path(ROOT),true),"delete failed");
        require(!f.exists(new Path(ROOT)),"cleanup left data");pass("cleanup");
      }
    }
  }
}

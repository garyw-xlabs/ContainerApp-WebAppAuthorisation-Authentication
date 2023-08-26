import type { GetServerSideProps, NextPage } from 'next';

interface PageProps {
  headers: {header:[string, string | string[] | undefined]}[];
}

export const getServerSideProps: GetServerSideProps<PageProps> = async ({
  req,
}) => {
  let headerValues = Object.entries(req.headers);
 
  const headers: {header: [string, string | string[] | undefined]}[] = [];
  
 
  for (const pair of headerValues.entries()) {
    headers.push({header:pair[1]});
  }
  
  return {
    props: {
      headers : headers,
      
    },
  };
};

const Page: NextPage<PageProps> = ({  headers }) => { 
  
 return (
    <ul>      
      {headers.map((x,index)=> (<li key={index}>{JSON.stringify(x)}</li>))}
    </ul>
  );
};

export default Page;
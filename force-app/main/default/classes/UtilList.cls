/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public without sharing class UtilList {

    /**
     * @description split list to list of list
     * @param source List<SObject>
     * @param size size
     *
     * @return List<List<SObject>>
     */
    public List<List<SObject>> split(List<SObject> source, Integer size) {
        List<List<SObject>> ret = new List<List<SObject>>();
        if (source == null) return ret;

        // If the source size is equal to or smaller than our partition size, just return it
        if (source.size() <= size) {
            ret.add(source);
            return ret;
        }

        // Initialize the partitions
        Integer partition = 0;
        ret.add(new List<SObject>());

        for (SObject obj : source) {
            // Create a new partition when we fill one up
            if (ret[partition].size() == size) {
                partition++;
                ret.add(new List<SObject>());
            }
            // Add object to current partition
            ret[partition].add(obj);
        }
        return ret;
    }

    /**
     * @description split list to list of list
     * @param source List<Object>
     * @param size size
     *
     * @return List<List<Object>>
     *
     *  List<String> a = new List<String>{'a','b','c','d','e','f'};
     *  List<List<Object>> a1 = Core.List2.split(a, 2);
        for(List<Object> aaa : a1){
            for(Object aaaa : aaa){
                System.debug(String.valueOf(aaaa));
            }
        }
     */
    public List<List<Object>> split(List<Object> source, Integer size) {
        List<List<Object>> ret = new List<List<Object>>();
        if (source == null) return ret;

        // If the source size is equal to or smaller than our partition size, just return it
        if (source.size() <= size) {
            ret.add(source);
            return ret;
        }

        // Initialize the partitions
        Integer partition = 0;
        ret.add(new List<Object>());

        for (Object obj : source) {
            // Create a new partition when we fill one up
            if (ret[partition].size() == size) {
                partition++;
                ret.add(new List<Object>());
            }
            // Add object to current partition
            ret[partition].add(obj);
        }
        return ret;
    }

    public Boolean isBlank(List<Object> targetList){
        return (targetList == null || targetList.isEmpty()) ? true : false;
    }

}
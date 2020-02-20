package org.quicquid.genealogy.model;

import java.util.Set;


/**
 * @author titto
 */
public interface Individual {
    
    String getFirstName();
    
    String getNickName();
    
    String getFamilyName();
    
    Sex getSex();
    
    Event getBirth();    

    Event getDeath();

    Place getAddress();
    
    Family getFamilyOfBirth();
    
    Set<Family> getFamilies();

}

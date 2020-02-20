/*
 * Created on 26-Dec-2004
*/
package org.quicquid.genealogy.model;

import java.util.Set;


/**
 * @author titto
 */
public interface Family {

    Individual getFather();
    
    Individual getMother();
    
    Event getMarriage();
    
    Event getDivorce();
   
    Set<Individual> getChildren(); 
}

/*
 * Created on 26-Dec-2004
 */
package org.quicquid.genealogy.model;

/**
 * @author titto
 */
public interface Place extends Individual {

    String getCountry();

    // State, Region or County
    String getState();

    // Town, City or Village
    String getPlace();

    // Street or Road, including number
    String getStreet();

}

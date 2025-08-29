using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.ProductGroupsCommands.Add;
using Products.Api.Models;
using Products.Api.Queries.GroupsQuery.Get;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ProductGroupsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductGroupDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetProductGroupByNameQuery()));
        }
        // GET: api/Product_Groups
        //[HttpGet("[action]")]
        //public async Task<ActionResult<List<ProductGroupDto>>> GetById([FromQuery] int id)
        //{
        //    var productGroups = await _getProductGroupByIdQuery.GetById(id);
        //    if (productGroups == null)
        //    {
        //        return NotFound(new { message = $"Product Group with ID {id} not found." });
        //    }
        //    return Ok(productGroups);
        //}

        // Post: api/Product_Groups
        [HttpPost("[action]")]
        public async Task<ActionResult<ProductGroupDto>> CreateProductGroup([FromBody] CreateProductGroupRequest createrequest)
        {
            return Ok(await mediator.Send(new AddProductGroupcommand(createrequest)));
        }

        // PUT: api/Product_Groups/id
        //[HttpPut("{id}")]
        //public async Task<IActionResult> UpdateProductGroup(int id , [FromBody] ProductGroupUpdateDto dto)
        //{
        //    //var productGroup = await _db.ProductGroups.FindAsync(dto.Id);
        //    if (id != dto.Id)
        //        return NotFound(new { message = "Product Group not found" });
        //    var grouptoUpdate = await _db.ProductGroups
        //        .Include(pg => pg.ChildGroups)
        //        .FirstOrDefaultAsync(pg => pg.Id == id);
        //    if ( grouptoUpdate == null)
        //    {
        //        return NotFound(new { message = "Product Group not found" });
        //    }
        //    // Update the properties of the product group
        //    grouptoUpdate.Name = dto.Name;
        //    grouptoUpdate.ParentGroupId = dto.ParentGroupId;
        //    grouptoUpdate.Color = dto.Color;
        //    // Clear existing child groups and add new ones
        //    if (dto.ChildGroupIds != null)
        //    {
        //        grouptoUpdate.ChildGroups.Clear();
        //    }
        //    else
        //    {
        //        // Remove children not in the new list
        //        var currentChildIds = grouptoUpdate.ChildGroups.Select(cg => cg.Id).ToList();
        //        var idsToRemove = currentChildIds.Except(dto.ChildGroupIds).ToList();
        //        var childrenToRemove = grouptoUpdate.ChildGroups.Where(cg => idsToRemove.Contains(cg.Id)).ToList();
        //        foreach (var child in childrenToRemove)
        //            grouptoUpdate.ChildGroups.Remove(child);

        //        // Add new children
        //        var idsToAdd = dto.ChildGroupIds.Except(currentChildIds).ToList();
        //        var childrenToAdd = await _db.ProductGroups.Where(pg => idsToAdd.Contains(pg.Id)).ToListAsync();
        //        foreach (var child in childrenToAdd)
        //            grouptoUpdate.ChildGroups.Add(child);
        //    }
        //    await _db.SaveChangesAsync();
        //    return Ok(new { message = "Product Group updated successfully" });
        //}
        // DELETE: api/Product_Groups/id
        //[HttpDelete("{id}")]
        //public async Task<IActionResult> DeleteProductGroup(int id)
        //{
        //    var productGroup = await _db.ProductGroups.FindAsync(id);
        //    if (productGroup == null)
        //    {
        //        return NotFound(new { message = "Product Group not found" });
        //    }

        //    // Check if any other group references this as a parent
        //    bool hasChildren = await _db.ProductGroups.AnyAsync(pg => pg.ParentGroupId == id);
        //    if (hasChildren)
        //    {
        //        return BadRequest(new { message = "Cannot delete a product group that has child groups" });
        //    }

        //    _db.ProductGroups.Remove(productGroup);
        //    await _db.SaveChangesAsync();
        //    return Ok(new { message = "Product Group deleted successfully" });

        //}

    }
}

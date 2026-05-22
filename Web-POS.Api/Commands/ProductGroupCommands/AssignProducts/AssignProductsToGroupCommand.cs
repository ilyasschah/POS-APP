using Api.DataBase;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Commands.ProductGroupCommands.AssignProducts
{
    public class AssignProductsToGroupRequest
    {
        public int GroupId { get; set; }
        public int CompanyId { get; set; }
        public List<int> ProductIds { get; set; } = [];
    }

    public class AssignProductsToGroupCommand : IRequest<int>
    {
        public AssignProductsToGroupRequest Request { get; }
        public AssignProductsToGroupCommand(AssignProductsToGroupRequest request) => Request = request;
    }

    public class AssignProductsToGroupCommandHandler
        : IRequestHandler<AssignProductsToGroupCommand, int>
    {
        private readonly AppDbContext _db;
        public AssignProductsToGroupCommandHandler(AppDbContext db) => _db = db;

        public async Task<int> Handle(AssignProductsToGroupCommand command, CancellationToken ct)
        {
            var req = command.Request;

            var groupExists = await _db.ProductGroups
                .AnyAsync(g => g.Id == req.GroupId && g.CompanyId == req.CompanyId, ct);
            if (!groupExists)
                throw new InvalidOperationException($"Group {req.GroupId} not found for company {req.CompanyId}.");

            var updated = await _db.Products
                .Where(p => p.CompanyId == req.CompanyId && req.ProductIds.Contains(p.Id))
                .ExecuteUpdateAsync(s => s.SetProperty(p => p.ProductGroupId, req.GroupId), ct);

            return updated;
        }
    }
}

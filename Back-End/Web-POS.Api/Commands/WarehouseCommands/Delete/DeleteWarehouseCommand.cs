using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.WarehouseCommands.Delete
{
    public class DeleteWarehouseCommand : IRequest<bool>
    {
        public int Id { get; }
        public int CompanyId { get; }
        public DeleteWarehouseCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }
        public class DeleteWarehouseCommandHandler : IRequestHandler<DeleteWarehouseCommand, bool>
        {
            private readonly WarehouseService _service;
            public DeleteWarehouseCommandHandler(WarehouseService service)
            {
                _service = service;
            }
            public async Task<bool> Handle(DeleteWarehouseCommand request, CancellationToken cancellationToken)
            {
                return await _service.DeleteAsync(request.Id, request.CompanyId);
            }
        }
    }
    public class DeleteWarehouseCommandValidator : AbstractValidator<DeleteWarehouseCommand>
    {
        public DeleteWarehouseCommandValidator()
        {
            RuleFor(c => c.Id).GreaterThan(0).WithMessage("Id must be valid.");
            RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId must be valid.");
        }
    }
}

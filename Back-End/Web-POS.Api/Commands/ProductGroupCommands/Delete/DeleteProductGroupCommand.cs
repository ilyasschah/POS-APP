using MediatR;
using Api.Services;
using FluentValidation;

namespace Api.Commands.ProductGroupCommands.Delete
{
    public class DeleteProductGroupCommand : IRequest<bool>
    {
        public int Id { get; }
        public int CompanyId { get; }

        public DeleteProductGroupCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteProductGroupCommandHandler : IRequestHandler<DeleteProductGroupCommand, bool>
        {
            private readonly ProductGroupService _service;

            public DeleteProductGroupCommandHandler(ProductGroupService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(DeleteProductGroupCommand command, CancellationToken cancellationToken)
            {
                return await _service.DeleteAsync(command.Id, command.CompanyId);
            }
        }
    }
    public class DeleteProductGroupCommandValidator : AbstractValidator<DeleteProductGroupCommand>
    {
        public DeleteProductGroupCommandValidator()
        {
            RuleFor(c => c.Id).GreaterThan(0).WithMessage("Id must be valid.");
            RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId must be valid.");
        }
    }
}
